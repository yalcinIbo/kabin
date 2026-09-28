import { z } from 'zod';
import { FieldValue, db } from '../lib/admin.js';
import { httpsError } from '../lib/https.js';
import { FP } from '../lib/paths.js';
import { loadImage } from '../lib/storage.js';
import { loadPricing } from '../config/pricing.js';
import { consumeDailyQuota } from '../credits/ledger.js';
import { providers } from '../providers/registry.js';
import type { ProviderSet } from '../providers/types.js';
import { type Caller, guardJob, idSchema, parseInput } from './common.js';

const Input = z.object({ garmentId: idSchema });

/** Kıyafet fotoğrafını Gemini ile analiz eder: kategori, renk, kumaş, başlık. */
export async function analyzeGarmentHandler(caller: Caller, raw: unknown, deps?: ProviderSet) {
  const { garmentId } = parseInput(Input, raw);
  const ref = db.doc(FP.garment(caller.uid, garmentId));
  const snap = await ref.get();
  if (!snap.exists) throw httpsError('not-found', 'Kıyafet bulunamadı.', 'not-found');
  if (snap.get('status') === 'ready') {
    return { status: 'ready', analysis: snap.get('analysis') ?? null, tryonSupported: snap.get('tryonSupported') === true };
  }

  const pricing = await loadPricing();
  await consumeDailyQuota(caller.uid, 'analysis', pricing.dailyCaps.analysis);

  return guardJob(async () => {
    const image = await loadImage(snap.get('storagePath') as string);
    const analysis = await (deps ?? providers()).vision().analyzeGarment(image);
    const { tryonSupported, ...fields } = analysis;
    const status = analysis.isGarment ? 'ready' : 'failed';
    await ref.update({
      status,
      analysis: fields,
      tryonSupported,
      errorTr: analysis.isGarment ? null : 'Fotoğrafta bir kıyafet algılanamadı. Kıyafeti tek başına, net bir şekilde çek.',
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { status, analysis: fields, tryonSupported };
  });
}
