import { logger } from 'firebase-functions/logger';
import { loadPricing } from '../config/pricing.js';
import { grantCredits } from '../credits/ledger.js';

/** Yeni profil oluşturulduğunda hoş geldin kredisi (idempotent: `ledger/welcome`). */
export async function grantWelcomeCredits(uid: string): Promise<boolean> {
  const pricing = await loadPricing();
  if (pricing.welcome <= 0) return false;
  const granted = await grantCredits({ uid, amount: pricing.welcome, entryId: 'welcome', note: 'Hoş geldin kredisi' });
  if (granted) logger.info('Hoş geldin kredisi verildi', { uid, amount: pricing.welcome });
  return granted;
}
