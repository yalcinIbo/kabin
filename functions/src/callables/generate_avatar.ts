import { z } from 'zod';
import { FieldValue, db } from '../lib/admin.js';
import { httpsError } from '../lib/https.js';
import { FP, SP } from '../lib/paths.js';
import { fileExists } from '../lib/storage.js';
import { dayKey, inMs } from '../lib/time.js';
import { loadFlags, loadPricing } from '../config/pricing.js';
import { assertCanSpend, writeDebit } from '../credits/ledger.js';
import { QUEUE_DEADLINE_MS } from '../jobs/runner.js';
import { type Caller, parseInput } from './common.js';

const Input = z.object({
  selfiePath: z.string().min(1).max(300),
  heightCm: z.number().int().min(120).max(230),
  weightKg: z.number().int().min(30).max(250),
  bodyType: z.enum(['slim', 'average', 'athletic', 'curvy', 'plus']),
  gender: z.enum(['female', 'male', 'unspecified']).default('unspecified'),
});

/** Selfie + ölçülerden stüdyo tipi boydan avatar üretimi için iş açar (`photos/{id}`, source=generated). */
export async function generateAvatarHandler(caller: Caller, raw: unknown) {
  const input = parseInput(Input, raw);
  const uid = caller.uid;
  if (!input.selfiePath.startsWith(SP.tmpPrefix(uid)) || input.selfiePath.includes('..')) {
    throw httpsError('permission-denied', 'Geçersiz selfie yolu.', 'bad-path');
  }
  const flags = await loadFlags();
  if (!flags.avatarEnabled) throw httpsError('unavailable', 'Avatar özelliği geçici olarak kapalı.', 'feature-disabled');
  if (!(await fileExists(input.selfiePath))) throw httpsError('not-found', 'Selfie bulunamadı. Lütfen tekrar yükle.', 'selfie-missing');

  const pricing = await loadPricing();
  const photoRef = db.collection(FP.photos(uid)).doc();
  const day = dayKey();
  const creditsLeft = await db.runTransaction(async (tx) => {
    const [user, usage] = await tx.getAll(db.doc(FP.user(uid)), db.doc(FP.usage(uid, day)));
    const check = assertCanSpend(user!, usage!, pricing.avatar, 'avatar', pricing.dailyCaps.avatar, day);
    const balance = writeDebit(tx, { uid, kind: 'avatar', jobId: photoRef.id, cost: pricing.avatar, capKey: 'avatar', check });
    tx.set(photoRef, {
      source: 'generated',
      status: 'pending',
      stage: null,
      progress: 0,
      storagePath: null,
      thumbPath: null,
      width: null,
      height: null,
      avatarParams: { ...input },
      qc: null,
      isDefault: false,
      cost: pricing.avatar,
      refundedAmount: 0,
      refunded: false,
      error: null,
      attempt: 0,
      leaseUntil: inMs(QUEUE_DEADLINE_MS),
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return balance;
  });
  return { photoId: photoRef.id, cost: pricing.avatar, creditsLeft };
}
