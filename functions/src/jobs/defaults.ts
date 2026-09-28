import { db } from '../lib/admin.js';
import { FP } from '../lib/paths.js';

/** Kullanıcının varsayılan fotoğrafı yoksa true (ilk uygun fotoğraf varsayılan olur). */
export async function hasNoDefaultPhoto(uid: string): Promise<boolean> {
  const snap = await db.collection(FP.photos(uid)).where('isDefault', '==', true).limit(1).get();
  return snap.empty;
}
