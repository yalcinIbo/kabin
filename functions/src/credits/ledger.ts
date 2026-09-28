import type { DocumentReference, DocumentSnapshot, Transaction } from 'firebase-admin/firestore';
import { FieldValue, Timestamp, db } from '../lib/admin.js';
import { httpsError } from '../lib/https.js';
import { FP } from '../lib/paths.js';
import { dayKey } from '../lib/time.js';
import type { DailyCaps } from '../config/pricing.js';

export type JobKind = 'tryon' | 'model3d' | 'avatar';
export type CapKey = keyof DailyCaps;
export type LedgerType = 'grant' | 'debit' | 'refund' | 'purchase';

/** Kısmi iadeler bu son eklerle ayrı ledger kaydı alır (ör. çoklu açı üretilemezse). */
export const PARTIAL_REFUND_SUFFIXES = ['multiview'] as const;
export type PartialRefundSuffix = (typeof PARTIAL_REFUND_SUFFIXES)[number];

export const debitId = (jobId: string) => `debit_${jobId}`;
export const refundId = (jobId: string, suffix?: string) => (suffix ? `refund_${jobId}_${suffix}` : `refund_${jobId}`);

export interface SpendCheck {
  creditsBefore: number;
  usageBefore: number;
  day: string;
}

/**
 * Transaction içinde okunmuş kullanıcı ve günlük kullanım belgelerine göre harcama yapılabilir mi?
 * Uygun değilse Türkçe mesajlı `resource-exhausted` fırlatır.
 */
export function assertCanSpend(
  user: DocumentSnapshot,
  usage: DocumentSnapshot,
  cost: number,
  capKey: CapKey,
  cap: number,
  day: string,
): SpendCheck {
  if (!user.exists) {
    throw httpsError('failed-precondition', 'Profil bulunamadı. Lütfen kaydı tamamlayın.', 'no-profile');
  }
  const credits = typeof user.get('credits') === 'number' ? (user.get('credits') as number) : 0;
  if (credits < cost) {
    throw httpsError(
      'resource-exhausted',
      `Bu işlem için ${cost} kredi gerekiyor, bakiyeniz ${credits}.`,
      'insufficient-credits',
      { required: cost, available: credits },
    );
  }
  const used = typeof usage.get(capKey) === 'number' ? (usage.get(capKey) as number) : 0;
  if (used >= cap) {
    throw httpsError(
      'resource-exhausted',
      'Bugünkü kullanım sınırına ulaştınız. Yarın tekrar deneyebilirsiniz.',
      'daily-cap',
      { cap },
    );
  }
  return { creditsBefore: credits, usageBefore: used, day };
}

/** Ücretsiz ama günlük sınırlı işlemler (analiz) için sayaç kontrolü ve artışı. */
export async function consumeDailyQuota(uid: string, capKey: CapKey, cap: number): Promise<void> {
  const day = dayKey();
  const ref = db.doc(FP.usage(uid, day));
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const used = typeof snap.get(capKey) === 'number' ? (snap.get(capKey) as number) : 0;
    if (used >= cap) {
      throw httpsError(
        'resource-exhausted',
        'Bugünkü analiz sınırına ulaştınız. Yarın tekrar deneyebilirsiniz.',
        'daily-cap',
        { cap },
      );
    }
    tx.set(ref, { [capKey]: used + 1, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  });
}

/** Krediyi düşer, günlük sayacı artırır ve `debit_{jobId}` kaydını yazar. Okumalar önceden yapılmış olmalı. */
export function writeDebit(
  tx: Transaction,
  args: { uid: string; kind: JobKind; jobId: string; cost: number; capKey: CapKey; check: SpendCheck },
): number {
  const { uid, kind, jobId, cost, capKey, check } = args;
  const balanceAfter = check.creditsBefore - cost;
  tx.update(db.doc(FP.user(uid)), { credits: balanceAfter, updatedAt: FieldValue.serverTimestamp() });
  tx.set(
    db.doc(FP.usage(uid, check.day)),
    { [capKey]: check.usageBefore + 1, updatedAt: FieldValue.serverTimestamp() },
    { merge: true },
  );
  tx.set(db.doc(FP.ledgerEntry(uid, debitId(jobId))), {
    type: 'debit' satisfies LedgerType,
    amount: -cost,
    balanceAfter,
    jobType: kind,
    jobId,
    usageDay: check.day,
    capKey,
    note: null,
    createdAt: FieldValue.serverTimestamp(),
  });
  return balanceAfter;
}

/**
 * İade. `amount` verilmezse kalan tutarın tamamı iade edilir (tam iade) ve günlük sayaç geri alınır.
 * Aynı `suffix` ile ikinci çağrı etkisizdir (idempotent). İade edilen kredi miktarını döner.
 */
export async function refundJob(args: {
  uid: string;
  kind: JobKind;
  jobId: string;
  jobRef?: DocumentReference;
  amount?: number;
  suffix?: PartialRefundSuffix;
  note?: string;
}): Promise<number> {
  const { uid, kind, jobId, jobRef, amount, suffix, note } = args;
  const userRef = db.doc(FP.user(uid));
  const debitRef = db.doc(FP.ledgerEntry(uid, debitId(jobId)));
  const entryRef = db.doc(FP.ledgerEntry(uid, refundId(jobId, suffix)));
  const partialRefs = PARTIAL_REFUND_SUFFIXES.map((s) => db.doc(FP.ledgerEntry(uid, refundId(jobId, s))));
  const fullRef = db.doc(FP.ledgerEntry(uid, refundId(jobId)));

  return db.runTransaction(async (tx) => {
    const refs = [userRef, debitRef, entryRef, fullRef, ...partialRefs, ...(jobRef ? [jobRef] : [])];
    const snaps = await tx.getAll(...refs);
    const [user, debit, entry, full] = snaps as [DocumentSnapshot, DocumentSnapshot, DocumentSnapshot, DocumentSnapshot];
    const partials = snaps.slice(4, 4 + partialRefs.length);
    const job = jobRef ? snaps[snaps.length - 1] : undefined;

    if (entry.exists || full.exists || !debit.exists || !user.exists) return 0;
    const cost = Math.abs((debit.get('amount') as number) ?? 0);
    const alreadyRefunded = partials.reduce((sum, p) => sum + (p.exists ? ((p.get('amount') as number) ?? 0) : 0), 0);
    const remaining = cost - alreadyRefunded;
    const value = amount === undefined ? remaining : Math.min(amount, remaining);
    if (value <= 0) return 0;

    const credits = ((user.get('credits') as number) ?? 0) + value;
    const refundedTotal = alreadyRefunded + value;
    tx.update(userRef, { credits, updatedAt: FieldValue.serverTimestamp() });
    tx.set(entryRef, {
      type: 'refund' satisfies LedgerType,
      amount: value,
      balanceAfter: credits,
      jobType: kind,
      jobId,
      note: note ?? null,
      createdAt: FieldValue.serverTimestamp(),
    });
    if (amount === undefined) {
      const day = debit.get('usageDay') as string | undefined;
      const capKey = debit.get('capKey') as string | undefined;
      if (day && capKey) {
        tx.set(db.doc(FP.usage(uid, day)), { [capKey]: FieldValue.increment(-1) }, { merge: true });
      }
    }
    if (job?.exists) {
      tx.update(job.ref, {
        refundedAmount: refundedTotal,
        refunded: refundedTotal >= cost,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    return value;
  });
}

/** Idempotent kredi yüklemesi (hoş geldin, yönetici hediyesi, ileride satın alma). */
export async function grantCredits(args: {
  uid: string;
  amount: number;
  entryId: string;
  type?: Extract<LedgerType, 'grant' | 'purchase'>;
  note?: string;
}): Promise<boolean> {
  const { uid, amount, entryId, type = 'grant', note } = args;
  if (!Number.isInteger(amount) || amount <= 0) throw new Error('Geçersiz kredi miktarı');
  const userRef = db.doc(FP.user(uid));
  const entryRef = db.doc(FP.ledgerEntry(uid, entryId));
  return db.runTransaction(async (tx) => {
    const [user, entry] = await tx.getAll(userRef, entryRef);
    if (!user?.exists || entry?.exists) return false;
    const credits = ((user.get('credits') as number) ?? 0) + amount;
    tx.update(userRef, { credits, updatedAt: FieldValue.serverTimestamp() });
    tx.set(entryRef, {
      type,
      amount,
      balanceAfter: credits,
      jobType: null,
      jobId: null,
      note: note ?? null,
      createdAt: FieldValue.serverTimestamp(),
    });
    return true;
  });
}

export function nowTs(): Timestamp {
  return Timestamp.now();
}
