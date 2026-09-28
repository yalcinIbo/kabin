import { logger } from 'firebase-functions/logger';
import { auth, db } from '../lib/admin.js';
import { httpsError } from '../lib/https.js';
import { FP, SP } from '../lib/paths.js';
import { deletePrefix } from '../lib/storage.js';
import type { Caller } from './common.js';

/** Kullanıcının tüm Firestore belgelerini ve Storage dosyalarını siler (KVKK). İdempotent. */
export async function purgeUserData(uid: string): Promise<void> {
  await db.recursiveDelete(db.doc(FP.user(uid)));
  await deletePrefix(SP.userRoot(uid));
  logger.info('Kullanıcı verileri silindi', { uid });
}

const RECENT_LOGIN_SECONDS = 10 * 60;

/** Hesabı ve tüm verileri kalıcı olarak siler. Son 10 dakika içinde yeniden giriş şarttır. */
export async function deleteMyAccountHandler(caller: Caller) {
  const now = Math.floor(Date.now() / 1000);
  if (!caller.authTime || now - caller.authTime > RECENT_LOGIN_SECONDS) {
    throw httpsError('failed-precondition', 'Güvenlik için lütfen yeniden giriş yapıp tekrar deneyin.', 'requires-recent-login');
  }
  await purgeUserData(caller.uid);
  await auth.deleteUser(caller.uid).catch((e: { code?: string }) => {
    if (e.code !== 'auth/user-not-found') throw e;
  });
  return { ok: true };
}
