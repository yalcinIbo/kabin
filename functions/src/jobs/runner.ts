import type { DocumentData, DocumentReference } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/logger';
import { FieldValue, Timestamp, db } from '../lib/admin.js';
import { JobError, toJobError } from '../lib/job_error.js';
import { refundJob, type JobKind } from '../credits/ledger.js';

export interface JobStatuses {
  queued: string;
  processing: string;
  done: string;
  failed: string;
}

/** Her iş türünün belge durum değerleri. Avatar işi `photos` belgesinin kendisidir. */
export const JOB_STATUSES: Record<JobKind, JobStatuses> = {
  tryon: { queued: 'queued', processing: 'processing', done: 'done', failed: 'failed' },
  model3d: { queued: 'queued', processing: 'processing', done: 'done', failed: 'failed' },
  avatar: { queued: 'pending', processing: 'processing', done: 'ready', failed: 'failed' },
};

/** Kuyrukta bekleme süresi: tetikleyici bu süre içinde çalışmazsa süpürücü işi iade eder. */
export const QUEUE_DEADLINE_MS = 15 * 60_000;

export interface JobContext {
  uid: string;
  jobId: string;
  ref: DocumentReference;
  data: DocumentData;
}

export type ProgressFn = (stage: string, progress: number) => Promise<void>;
export type JobWork = (ctx: JobContext, progress: ProgressFn) => Promise<Record<string, unknown>>;

/**
 * `queued → processing` geçişini transaction ile yapar. Tetikleyici birden fazla teslim edilirse
 * yalnızca ilki işi alır; diğerleri `null` döner.
 */
export async function claimJob(ref: DocumentReference, kind: JobKind, leaseMs: number): Promise<DocumentData | null> {
  const st = JOB_STATUSES[kind];
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists || snap.get('status') !== st.queued) return null;
    const attempt = ((snap.get('attempt') as number | undefined) ?? 0) + 1;
    tx.update(ref, {
      status: st.processing,
      attempt,
      stage: 'starting',
      progress: 0.05,
      leaseUntil: Timestamp.fromMillis(Date.now() + leaseMs),
      startedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { ...snap.data(), attempt };
  });
}

/** İşi `failed` yapar (yalnızca hâlâ aktifse). Geçiş yapıldıysa true. */
export async function failJob(ref: DocumentReference, kind: JobKind, err: JobError): Promise<boolean> {
  const st = JOB_STATUSES[kind];
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return false;
    const status = snap.get('status');
    if (status !== st.queued && status !== st.processing) return false;
    tx.update(ref, {
      status: st.failed,
      stage: null,
      leaseUntil: null,
      error: { code: err.code, messageTr: err.messageTr },
      finishedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return true;
  });
}

export async function runJob(opts: {
  kind: JobKind;
  uid: string;
  jobId: string;
  ref: DocumentReference;
  leaseMs: number;
  work: JobWork;
}): Promise<'done' | 'failed' | 'skipped'> {
  const { kind, uid, jobId, ref, leaseMs, work } = opts;
  const st = JOB_STATUSES[kind];
  const data = await claimJob(ref, kind, leaseMs);
  if (!data) {
    logger.info('İş alınmadı (zaten işlendi veya iptal)', { kind, uid, jobId });
    return 'skipped';
  }

  const progress: ProgressFn = async (stage, value) => {
    await ref
      .update({ stage, progress: Math.max(0, Math.min(0.99, value)), updatedAt: FieldValue.serverTimestamp() })
      .catch(() => undefined);
  };

  try {
    const result = await work({ uid, jobId, ref, data }, progress);
    const committed = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists || snap.get('status') !== st.processing) return false;
      tx.update(ref, {
        ...result,
        status: st.done,
        stage: null,
        progress: 1,
        leaseUntil: null,
        error: null,
        finishedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return true;
    });
    if (!committed) {
      logger.warn('İş sonucu yazılmadı: belge artık işleniyor durumunda değil', { kind, uid, jobId });
      return 'failed';
    }
    return 'done';
  } catch (err) {
    const jobErr = toJobError(err);
    logger.error('İş başarısız', { kind, uid, jobId, code: jobErr.code, detail: jobErr.detail ?? jobErr.message });
    await failJob(ref, kind, jobErr).catch((e) => logger.error('failJob hatası', e));
    await refundJob({ uid, kind, jobId, jobRef: ref, note: jobErr.code }).catch((e) =>
      logger.error('İade başarısız', { kind, uid, jobId, error: String(e) }),
    );
    return 'failed';
  }
}
