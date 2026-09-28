import { z } from 'zod';
import { FieldValue, db } from '../lib/admin.js';
import { httpsError } from '../lib/https.js';
import { imageSize } from '../lib/imaging.js';
import { FP } from '../lib/paths.js';
import { loadImage } from '../lib/storage.js';
import { loadPricing } from '../config/pricing.js';
import { consumeDailyQuota } from '../credits/ledger.js';
import { hasNoDefaultPhoto } from '../jobs/defaults.js';
import { providers } from '../providers/registry.js';
import type { ProviderSet } from '../providers/types.js';
import { type Caller, guardJob, idSchema, parseInput } from './common.js';

const Input = z.object({ photoId: idSchema });

/** Yüklenen boydan fotoğrafı Gemini ile kalite kontrolünden geçirir: `pending → ready | rejected`. */
export async function checkPhotoHandler(caller: Caller, raw: unknown, deps?: ProviderSet) {
  const { photoId } = parseInput(Input, raw);
  const ref = db.doc(FP.photo(caller.uid, photoId));
  const snap = await ref.get();
  if (!snap.exists) throw httpsError('not-found', 'Fotoğraf bulunamadı.', 'not-found');
  if (snap.get('source') !== 'upload') throw httpsError('failed-precondition', 'Bu fotoğraf kontrol edilemez.', 'not-upload');
  const status = snap.get('status') as string;
  if (status === 'ready' || status === 'rejected') {
    return { status, qc: snap.get('qc') ?? null, isDefault: snap.get('isDefault') === true };
  }

  const pricing = await loadPricing();
  await consumeDailyQuota(caller.uid, 'analysis', pricing.dailyCaps.analysis);

  return guardJob(async () => {
    const image = await loadImage(snap.get('storagePath') as string);
    const qc = await (deps ?? providers()).vision().checkPhoto(image);
    const size = await imageSize(image);
    const isDefault = qc.passed && (snap.get('isDefault') === true || (await hasNoDefaultPhoto(caller.uid)));
    const nextStatus = qc.passed ? 'ready' : 'rejected';
    await ref.update({
      status: nextStatus,
      qc: { ...qc, checkedAt: FieldValue.serverTimestamp() },
      ...size,
      isDefault,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { status: nextStatus, qc, isDefault };
  });
}
