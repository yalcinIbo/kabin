import type { DocumentData, DocumentReference } from 'firebase-admin/firestore';
import { z } from 'zod';
import { FieldValue, db } from '../lib/admin.js';
import { httpsError } from '../lib/https.js';
import { toJpeg } from '../lib/imaging.js';
import { FP, SP } from '../lib/paths.js';
import { loadImage, saveImage } from '../lib/storage.js';
import { providerPhotoType, tryonCategory, isTryOnCategory } from '../ai/schemas.js';
import { runPair } from '../benchmark/runner.js';
import { providers } from '../providers/registry.js';
import type { ProviderPhotoType, ProviderSet, TryOnCategory } from '../providers/types.js';
import { type Caller, idSchema, parseInput } from './common.js';

const Input = z.object({
  photoId: idSchema,
  garmentIds: z.array(idSchema).min(1).max(10),
  providers: z.array(z.enum(['fashn', 'vertex', 'gemini'])).min(1).max(3).default(['fashn', 'vertex']),
});

/** Yönetici: seçilen fotoğraf × kıyafetler için sağlayıcı karşılaştırma koşusu açar (kredi düşmez). */
export async function runBenchmarkHandler(caller: Caller, raw: unknown) {
  if (!caller.isAdmin) throw httpsError('permission-denied', 'Bu işlem yalnızca yöneticiler içindir.', 'admin-only');
  const input = parseInput(Input, raw);
  const uid = caller.uid;
  const photo = await db.doc(FP.photo(uid, input.photoId)).get();
  if (!photo.exists || photo.get('status') !== 'ready') throw httpsError('failed-precondition', 'Fotoğraf hazır değil.', 'photo-not-ready');
  const garments = await db.getAll(...input.garmentIds.map((id) => db.doc(FP.garment(uid, id))));
  const usable = garments.filter(
    (g) => g.exists && g.get('status') === 'ready' && isTryOnCategory((g.get('analysis.category') as string) ?? 'other'),
  );
  if (usable.length === 0) throw httpsError('failed-precondition', 'Denenebilir kıyafet yok.', 'no-garments');

  const runRef = db.collection(FP.benchmarks).doc();
  const batch = db.batch();
  batch.set(runRef, {
    createdBy: uid,
    providers: input.providers,
    photoId: input.photoId,
    pairCount: usable.length,
    doneCount: 0,
    createdAt: FieldValue.serverTimestamp(),
  });
  for (const g of usable) {
    const pairRef = runRef.collection('pairs').doc(g.id);
    batch.set(pairRef, {
      status: 'queued',
      providers: input.providers,
      photoPath: photo.get('storagePath'),
      photoThumbPath: photo.get('thumbPath') ?? null,
      garmentId: g.id,
      garmentPath: g.get('storagePath'),
      garmentThumbPath: g.get('thumbPath') ?? null,
      garmentIsolatedPath: g.get('isolatedPath') ?? null,
      garmentTitle: g.get('analysis.titleTr') ?? null,
      category: tryonCategory(g.get('analysis.category') as string),
      garmentPhotoType: providerPhotoType((g.get('analysis.garmentPhotoType') as string) ?? 'auto'),
      results: {},
      rating: null,
      createdAt: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
  return { runId: runRef.id, pairCount: usable.length };
}

/** Karşılaştırma çiftini işler: her sağlayıcıyı ayrı çalıştırır, görselleri ve ölçümleri yazar. */
export async function processBenchmarkPair(runId: string, ref: DocumentReference, deps: ProviderSet = providers()) {
  const data = await db.runTransaction(async (tx): Promise<DocumentData | null> => {
    const snap = await tx.get(ref);
    if (!snap.exists || snap.get('status') !== 'queued') return null;
    tx.update(ref, { status: 'processing', startedAt: FieldValue.serverTimestamp() });
    return snap.data() ?? null;
  });
  if (!data) return;

  const [person, garment, isolated] = await Promise.all([
    loadImage(data.photoPath as string),
    loadImage(data.garmentPath as string),
    data.garmentIsolatedPath ? loadImage(data.garmentIsolatedPath as string, { keepAlpha: true }).catch(() => null) : Promise.resolve(null),
  ]);
  const ids = (data.providers as Array<'fashn' | 'vertex' | 'gemini'>) ?? ['fashn'];
  const runs = await runPair(ids.map((id) => deps.tryOn(id)), {
    person,
    garment,
    garmentIsolated: isolated,
    category: data.category as TryOnCategory,
    garmentPhotoType: data.garmentPhotoType as ProviderPhotoType,
    seed: 42,
  });

  const results: Record<string, unknown> = {};
  for (const [i, r] of runs.entries()) {
    const key = ids[i]!;
    if (r.ok && r.image) {
      const path = SP.benchmarkResult(runId, ref.id, key);
      await saveImage(path, await toJpeg(r.image));
      results[key] = { storagePath: path, ms: r.ms, costUsd: r.costUsd, error: null, actualProvider: r.provider };
    } else {
      results[key] = { storagePath: null, ms: r.ms, costUsd: 0, error: r.error ?? 'bilinmeyen hata', actualProvider: r.provider };
    }
  }
  await ref.update({ status: 'done', results, finishedAt: FieldValue.serverTimestamp() });
  await db.doc(FP.benchmark(runId)).update({ doneCount: FieldValue.increment(1) }).catch(() => undefined);
}
