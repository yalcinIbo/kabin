import { z } from 'zod';
import { FieldValue, db } from '../lib/admin.js';
import { httpsError } from '../lib/https.js';
import { FP } from '../lib/paths.js';
import { dayKey, inMs } from '../lib/time.js';
import { loadFlags, loadPricing } from '../config/pricing.js';
import { assertCanSpend, writeDebit } from '../credits/ledger.js';
import { QUEUE_DEADLINE_MS } from '../jobs/runner.js';
import { providerDefaults } from '../providers/registry.js';
import { type Caller, idSchema, parseInput } from './common.js';

const Input = z.object({ tryonId: idSchema });

/** Tamamlanmış bir denemeden 3D model işi açar. Aynı deneme için aktif/başarılı iş varsa onu döner. */
export async function requestModel3DHandler(caller: Caller, raw: unknown) {
  const { tryonId } = parseInput(Input, raw);
  const flags = await loadFlags();
  if (!flags.model3dEnabled) throw httpsError('unavailable', '3D model özelliği geçici olarak kapalı.', 'feature-disabled');
  const pricing = await loadPricing();
  const uid = caller.uid;
  const tryonRef = db.doc(FP.tryon(uid, tryonId));
  const day = dayKey();

  return db.runTransaction(async (tx) => {
    const tryon = await tx.get(tryonRef);
    if (!tryon.exists) throw httpsError('not-found', 'Deneme bulunamadı.', 'not-found');
    if (tryon.get('status') !== 'done') throw httpsError('failed-precondition', 'Deneme henüz tamamlanmadı.', 'tryon-not-done');

    const existingId = tryon.get('model3dRequestId') as string | null;
    if (existingId) {
      const existing = await tx.get(db.doc(FP.model3d(uid, existingId)));
      if (existing.exists && existing.get('status') !== 'failed') {
        const user = await tx.get(db.doc(FP.user(uid)));
        return { modelId: existingId, cost: 0, creditsLeft: (user.get('credits') as number) ?? 0, existing: true };
      }
    }

    const results = (tryon.get('results') ?? []) as Array<{ angle: string; storagePath: string }>;
    const source = results.find((r) => r.angle === 'front')?.storagePath;
    if (!source) throw httpsError('failed-precondition', 'Denemenin ön görünümü bulunamadı.', 'no-front');

    const [user, usage] = await tx.getAll(db.doc(FP.user(uid)), db.doc(FP.usage(uid, day)));
    const check = assertCanSpend(user!, usage!, pricing.model3d, 'model3d', pricing.dailyCaps.model3d, day);
    const modelRef = db.collection(FP.models3d(uid)).doc();
    const balance = writeDebit(tx, { uid, kind: 'model3d', jobId: modelRef.id, cost: pricing.model3d, capKey: 'model3d', check });
    tx.set(modelRef, {
      status: 'queued',
      stage: null,
      progress: 0,
      tryonId,
      sourcePath: source,
      tryonThumbPath: tryon.get('thumbPath') ?? null,
      provider: providerDefaults().model3d,
      cost: pricing.model3d,
      refundedAmount: 0,
      refunded: false,
      glbPath: null,
      previewPath: null,
      isolatedPath: null,
      fileSizeBytes: null,
      error: null,
      attempt: 0,
      leaseUntil: inMs(QUEUE_DEADLINE_MS),
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.update(tryonRef, { model3dRequestId: modelRef.id, updatedAt: FieldValue.serverTimestamp() });
    return { modelId: modelRef.id, cost: pricing.model3d, creditsLeft: balance, existing: false };
  });
}
