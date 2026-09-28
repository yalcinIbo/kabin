import { logger } from 'firebase-functions/logger';
import { Timestamp, db } from '../lib/admin.js';
import { JobError } from '../lib/job_error.js';
import { refundJob, type JobKind } from '../credits/ledger.js';
import { JOB_STATUSES, failJob } from './runner.js';

const GROUPS: Array<{ group: string; kind: JobKind }> = [
  { group: 'tryons', kind: 'tryon' },
  { group: 'models3d', kind: 'model3d' },
  { group: 'photos', kind: 'avatar' },
];

/**
 * Süresi dolmuş (kuyrukta takılmış veya işlenirken zaman aşımına uğramış) işleri `failed` yapar
 * ve krediyi iade eder. Yüklenen fotoğrafların `leaseUntil` alanı olmadığı için etkilenmez.
 */
export async function sweepStuckJobs(now: Timestamp = Timestamp.now()): Promise<number> {
  let swept = 0;
  for (const { group, kind } of GROUPS) {
    const st = JOB_STATUSES[kind];
    const snap = await db
      .collectionGroup(group)
      .where('status', 'in', [st.queued, st.processing])
      .where('leaseUntil', '<', now)
      .limit(200)
      .get();
    for (const doc of snap.docs) {
      const uid = doc.ref.parent.parent?.id;
      if (!uid) continue;
      const err = new JobError('timeout', 'İşlem zaman aşımına uğradı. Krediniz iade edildi.');
      const failed = await failJob(doc.ref, kind, err);
      if (failed) {
        await refundJob({ uid, kind, jobId: doc.id, jobRef: doc.ref, note: 'timeout' });
        swept++;
      }
    }
  }
  if (swept) logger.warn('Takılan işler iade edildi', { swept });
  return swept;
}
