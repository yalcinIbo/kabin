import { z } from 'zod';
import { FieldValue, db } from '../lib/admin.js';
import { httpsError } from '../lib/https.js';
import { FP } from '../lib/paths.js';
import { dayKey, inMs } from '../lib/time.js';
import { isTryOnCategory, providerPhotoType, tryonCategory } from '../ai/schemas.js';
import { loadFlags, loadPricing } from '../config/pricing.js';
import { assertCanSpend, writeDebit } from '../credits/ledger.js';
import { QUEUE_DEADLINE_MS } from '../jobs/runner.js';
import { providerDefaults } from '../providers/registry.js';
import { type Caller, idSchema, parseInput } from './common.js';

const Input = z.object({
  photoId: idSchema,
  garmentId: idSchema,
  multiView: z.boolean().default(true),
  provider: z.enum(['fashn', 'vertex', 'gemini', 'both']).optional(),
});

/** Krediyi atomik düşer ve `tryons/{jobId}` belgesini `queued` olarak yazar; işi tetikleyici yapar. */
export async function requestTryOnHandler(caller: Caller, raw: unknown) {
  const input = parseInput(Input, raw);
  if (input.provider && !caller.isAdmin) {
    throw httpsError('permission-denied', 'Sağlayıcı seçimi yalnızca yöneticiler içindir.', 'admin-only');
  }
  const flags = await loadFlags();
  if (!flags.tryonEnabled) throw httpsError('unavailable', 'Deneme özelliği geçici olarak kapalı.', 'feature-disabled');

  const pricing = await loadPricing();
  const cost = pricing.tryon + (input.multiView ? pricing.multiView : 0);
  const provider = input.provider ?? providerDefaults().tryon;
  const uid = caller.uid;
  const jobRef = db.collection(FP.tryons(uid)).doc();
  const day = dayKey();

  const creditsLeft = await db.runTransaction(async (tx) => {
    const [user, usage, photo, garment] = await tx.getAll(
      db.doc(FP.user(uid)),
      db.doc(FP.usage(uid, day)),
      db.doc(FP.photo(uid, input.photoId)),
      db.doc(FP.garment(uid, input.garmentId)),
    );
    const check = assertCanSpend(user!, usage!, cost, 'tryon', pricing.dailyCaps.tryon, day);
    if (!photo?.exists || photo.get('status') !== 'ready' || !photo.get('storagePath')) {
      throw httpsError('failed-precondition', 'Seçilen fotoğraf hazır değil.', 'photo-not-ready');
    }
    if (!garment?.exists || garment.get('status') !== 'ready') {
      throw httpsError('failed-precondition', 'Seçilen kıyafet hazır değil.', 'garment-not-ready');
    }
    const analysis = (garment.get('analysis') ?? {}) as Record<string, string | undefined>;
    const category = analysis.category ?? 'other';
    if (!isTryOnCategory(category)) {
      throw httpsError('failed-precondition', 'Bu kıyafet türü henüz denenemiyor (ayakkabı ve aksesuar desteklenmiyor).', 'unsupported-category');
    }

    const balance = writeDebit(tx, { uid, kind: 'tryon', jobId: jobRef.id, cost, capKey: 'tryon', check });
    tx.set(jobRef, {
      status: 'queued',
      stage: null,
      progress: 0,
      photoId: input.photoId,
      garmentId: input.garmentId,
      photoPath: photo.get('storagePath'),
      photoThumbPath: photo.get('thumbPath') ?? null,
      garmentPath: garment.get('storagePath'),
      garmentThumbPath: garment.get('thumbPath') ?? null,
      garmentIsolatedPath: garment.get('isolatedPath') ?? null,
      category: tryonCategory(category),
      garmentPhotoType: providerPhotoType(analysis.garmentPhotoType ?? 'auto'),
      garmentInfo: {
        titleTr: analysis.titleTr ?? null,
        category,
        colorNameTr: analysis.colorNameTr ?? null,
        fabricGuess: analysis.fabricGuess ?? null,
      },
      measurements: {
        heightCm: user!.get('heightCm') ?? null,
        weightKg: user!.get('weightKg') ?? null,
        bodyType: user!.get('bodyType') ?? null,
      },
      provider,
      options: { multiView: input.multiView, numSamples: 1, mode: 'balanced' },
      cost,
      costBreakdown: { tryon: pricing.tryon, multiView: input.multiView ? pricing.multiView : 0 },
      refundedAmount: 0,
      refunded: false,
      results: [],
      thumbPath: null,
      styleAdvice: null,
      error: null,
      attempt: 0,
      model3dId: null,
      model3dRequestId: null,
      leaseUntil: inMs(QUEUE_DEADLINE_MS),
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return balance;
  });

  return { jobId: jobRef.id, cost, creditsLeft };
}
