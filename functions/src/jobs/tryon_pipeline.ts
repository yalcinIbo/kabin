import { logger } from 'firebase-functions/logger';
import { FieldValue, db } from '../lib/admin.js';
import { imageSize, thumbnail, toJpeg } from '../lib/imaging.js';
import { FP, SP } from '../lib/paths.js';
import { loadImage, saveImage } from '../lib/storage.js';
import { refundJob } from '../credits/ledger.js';
import { providers } from '../providers/registry.js';
import type { ImageBuf, ProviderPhotoType, ProviderSet, TryOnCategory, TryOnChoice, ViewAngle } from '../providers/types.js';
import type { JobContext, ProgressFn } from './runner.js';

export interface TryOnJobData {
  photoPath: string;
  garmentId: string;
  garmentPath: string;
  garmentIsolatedPath?: string | null;
  category: TryOnCategory;
  garmentPhotoType: ProviderPhotoType;
  provider: TryOnChoice;
  options?: { multiView?: boolean; numSamples?: number; mode?: 'performance' | 'balanced' | 'quality' };
  costBreakdown?: { tryon: number; multiView: number };
  garmentInfo?: { titleTr?: string; category?: string; colorNameTr?: string; fabricGuess?: string } | null;
  measurements?: { heightCm?: number | null; weightKg?: number | null; bodyType?: string | null } | null;
}

export interface TryOnResultEntry {
  provider: string;
  angle: 'front' | ViewAngle;
  storagePath: string;
  width: number;
  height: number;
}

export async function processTryOn(ctx: JobContext, progress: ProgressFn, deps: ProviderSet = providers()): Promise<Record<string, unknown>> {
  const { uid, jobId } = ctx;
  const d = ctx.data as TryOnJobData;

  await progress('preparing', 0.08);
  const [person, garment, isolated] = await Promise.all([
    loadImage(d.photoPath),
    loadImage(d.garmentPath),
    d.garmentIsolatedPath ? loadImage(d.garmentIsolatedPath, { keepAlpha: true }).catch(() => null) : Promise.resolve(null),
  ]);

  await progress('tryon', 0.15);
  const out = await deps.tryOn(d.provider).run({
    person,
    garment,
    garmentIsolated: isolated,
    category: d.category,
    garmentPhotoType: d.garmentPhotoType,
    numSamples: d.options?.numSamples ?? 1,
    mode: d.options?.mode ?? 'balanced',
  });

  if (out.garmentIsolated && !d.garmentIsolatedPath) {
    const path = SP.garmentIsolated(uid, d.garmentId);
    await saveImage(path, out.garmentIsolated)
      .then(() => db.doc(FP.garment(uid, d.garmentId)).update({ isolatedPath: path, updatedAt: FieldValue.serverTimestamp() }))
      .catch((e) => logger.warn('İzole kıyafet önbelleğe alınamadı', { error: String(e) }));
  }

  const results: TryOnResultEntry[] = [];
  const seen = new Map<string, number>();
  let primary: { image: ImageBuf; provider: string } | null = null;
  for (const tagged of out.images) {
    const n = (seen.get(tagged.provider) ?? 0) + 1;
    seen.set(tagged.provider, n);
    const name = n === 1 ? tagged.provider : `${tagged.provider}-${n}`;
    const image = await toJpeg(tagged.image);
    const path = SP.tryonImage(uid, jobId, name, 'front');
    await saveImage(path, image);
    const size = await imageSize(image);
    results.push({ provider: tagged.provider, angle: 'front', storagePath: path, ...size });
    primary ??= { image, provider: tagged.provider };
  }
  if (!primary) throw new Error('Try-on sonucu boş');

  const thumbPath = SP.tryonThumb(uid, jobId);
  await saveImage(thumbPath, await thumbnail(primary.image));
  await progress('tryon', 0.5);

  let multiViewFailed = false;
  const viewErrors: string[] = [];
  if (d.options?.multiView) {
    await progress('multiview', 0.55);
    const angles: ViewAngle[] = ['side', 'back'];
    const views = await Promise.allSettled(angles.map((a) => deps.multiView().generateView(primary!.image, a)));
    for (const [i, v] of views.entries()) {
      const angle = angles[i]!;
      if (v.status === 'rejected') {
        viewErrors.push(`${angle}: ${String(v.reason).slice(0, 200)}`);
        continue;
      }
      const image = await toJpeg(v.value);
      const path = SP.tryonImage(uid, jobId, primary.provider, angle);
      await saveImage(path, image);
      results.push({ provider: primary.provider, angle, storagePath: path, ...(await imageSize(image)) });
    }
    if (views.every((v) => v.status === 'rejected')) {
      multiViewFailed = true;
      const amount = d.costBreakdown?.multiView ?? 0;
      if (amount > 0) {
        await refundJob({ uid, kind: 'tryon', jobId, jobRef: ctx.ref, amount, suffix: 'multiview', note: 'Çoklu açı üretilemedi' }).catch((e) =>
          logger.error('Kısmi iade başarısız', { jobId, error: String(e) }),
        );
      }
    }
    if (viewErrors.length) logger.warn('Bazı açılar üretilemedi', { jobId, viewErrors });
  }

  await progress('advice', 0.85);
  let styleAdvice: Record<string, unknown> | null = null;
  try {
    const advice = await deps.vision().styleAdvice(primary.image, {
      garmentTitleTr: d.garmentInfo?.titleTr ?? null,
      garmentCategory: d.garmentInfo?.category ?? null,
      colorNameTr: d.garmentInfo?.colorNameTr ?? null,
      fabricGuess: d.garmentInfo?.fabricGuess ?? null,
      heightCm: d.measurements?.heightCm ?? null,
      weightKg: d.measurements?.weightKg ?? null,
      bodyType: d.measurements?.bodyType ?? null,
    });
    styleAdvice = { ...advice, generatedAt: FieldValue.serverTimestamp() };
  } catch (e) {
    logger.warn('Stil tavsiyesi üretilemedi', { jobId, error: String(e) });
  }

  await progress('saving', 0.95);
  return {
    results,
    thumbPath,
    styleAdvice,
    multiViewFailed,
    providerCostUsd: out.costUsd,
    providerDurationMs: out.durationMs,
    providerFailures: out.failures ?? [],
  };
}
