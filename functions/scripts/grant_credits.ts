/**
 * Kullanıcıya kredi yükler (idempotent ledger kaydı ile) ve isteğe bağlı yönetici yetkisi verir.
 *   Emülatör: npm run grant -- --uid <uid> --amount 20 --emulator
 *   Prod:     GOOGLE_APPLICATION_CREDENTIALS=servis-hesabi.json npm run grant -- --uid <uid> --amount 20 [--admin]
 */
import { parseArgs, useEmulatorEnv } from './args.js';

const args = parseArgs();
const PROJECT = (args.project as string) ?? 'kabin-app-2026';
if (args.emulator) useEmulatorEnv(PROJECT, `${PROJECT}.firebasestorage.app`);
else process.env.GCLOUD_PROJECT ??= PROJECT;

const uid = args.uid as string | undefined;
const amount = Number(args.amount ?? 0);
if (!uid) throw new Error('--uid gerekli');

const { auth } = await import('../src/lib/admin.js');
const { grantCredits } = await import('../src/credits/ledger.js');

if (amount > 0) {
  const entryId = (args.entry as string) ?? `grant_${Date.now()}`;
  const ok = await grantCredits({ uid, amount, entryId, note: (args.note as string) ?? 'Yönetici hediyesi' });
  console.log(ok ? `✔ ${amount} kredi yüklendi (${entryId})` : '• Kayıt zaten var veya kullanıcı profili yok, değişiklik yapılmadı.');
}
if (args.admin) {
  const user = await auth.getUser(uid);
  await auth.setCustomUserClaims(uid, { ...(user.customClaims ?? {}), admin: true });
  console.log('✔ Yönetici yetkisi verildi (kullanıcı yeniden giriş yapmalı).');
}
process.exit(0);
