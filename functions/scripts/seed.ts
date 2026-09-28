/**
 * Emülatöre test verisi yükler (yalnızca emülatör!).
 *   firebase emulators:start   (başka terminalde, kabin/ klasöründe)
 *   npm run seed
 * Oluşturur: test@kabin.dev / Test1234! (50 kredi, yönetici), config/pricing, config/flags,
 * hazır bir boydan fotoğraf ve iki kıyafet.
 */
import sharp from 'sharp';
import { parseArgs, useEmulatorEnv } from './args.js';

const args = parseArgs();
const PROJECT = (args.project as string) ?? 'kabin-app-2026';
useEmulatorEnv(PROJECT, (args.bucket as string) ?? `${PROJECT}.firebasestorage.app`);
if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Yalnızca emülatörde çalışır.');

const { auth, bucket, db, FieldValue } = await import('../src/lib/admin.js');
const { DEFAULT_FLAGS, DEFAULT_PRICING } = await import('../src/config/pricing.js');
const { FP } = await import('../src/lib/paths.js');

const EMAIL = (args.email as string) ?? 'test@kabin.dev';
const PASSWORD = (args.password as string) ?? 'Test1234!';

async function svgJpeg(width: number, height: number, svg: string): Promise<Buffer> {
  return sharp(Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}">${svg}</svg>`)).jpeg({ quality: 90 }).toBuffer();
}

async function upload(path: string, data: Buffer): Promise<void> {
  await bucket().file(path).save(data, {
    contentType: 'image/jpeg',
    resumable: false,
    metadata: { metadata: { firebaseStorageDownloadTokens: crypto.randomUUID() } },
  });
}

const user = await auth.getUserByEmail(EMAIL).catch(() => auth.createUser({ email: EMAIL, password: PASSWORD, displayName: 'Test Kullanıcı', emailVerified: true }));
await auth.setCustomUserClaims(user.uid, { admin: true });
const uid = user.uid;

await db.doc(FP.pricing).set(DEFAULT_PRICING);
await db.doc(FP.flags).set(DEFAULT_FLAGS);
await db.doc(FP.user(uid)).set(
  {
    displayName: 'Test Kullanıcı',
    email: EMAIL,
    credits: 50,
    heightCm: 172,
    weightKg: 68,
    bodyType: 'average',
    gender: 'unspecified',
    consent: { kvkkVersion: '2026-09', kvkkAccepted: true, aiTransferAccepted: true, acceptedAt: FieldValue.serverTimestamp() },
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  },
  { merge: true },
);
await db.doc(FP.ledgerEntry(uid, 'welcome')).set({ type: 'grant', amount: 50, balanceAfter: 50, jobType: null, jobId: null, note: 'Seed', createdAt: FieldValue.serverTimestamp() });

const person = await svgJpeg(
  720,
  1280,
  `<rect width="100%" height="100%" fill="#e7e5e4"/><circle cx="360" cy="190" r="85" fill="#d6a77a"/>
   <rect x="250" y="290" width="220" height="420" rx="40" fill="#9ca3af"/><rect x="190" y="300" width="55" height="360" rx="25" fill="#d6a77a"/>
   <rect x="475" y="300" width="55" height="360" rx="25" fill="#d6a77a"/><rect x="265" y="700" width="85" height="480" rx="30" fill="#374151"/>
   <rect x="370" y="700" width="85" height="480" rx="30" fill="#374151"/>`,
);
const photoId = 'seed-photo';
await upload(`users/${uid}/photos/${photoId}/original.jpg`, person);
await upload(`users/${uid}/photos/${photoId}/thumb.jpg`, await sharp(person).resize(270).jpeg().toBuffer());
await db.doc(FP.photo(uid, photoId)).set({
  source: 'upload',
  status: 'ready',
  storagePath: `users/${uid}/photos/${photoId}/original.jpg`,
  thumbPath: `users/${uid}/photos/${photoId}/thumb.jpg`,
  width: 720,
  height: 1280,
  isDefault: true,
  qc: { passed: true, issues: [], hintTr: 'Seed fotoğrafı', blocked: false },
  createdAt: FieldValue.serverTimestamp(),
  updatedAt: FieldValue.serverTimestamp(),
});

const garments = [
  { id: 'seed-tshirt', color: '#1e3a8a', title: 'Lacivert tişört', category: 'tops', colorName: 'lacivert', shape: '<path d="M150 120 L250 80 L350 80 L450 120 L520 220 L440 260 L420 200 L420 540 L180 540 L180 200 L160 260 L80 220 Z"/>' },
  { id: 'seed-skirt', color: '#b91c1c', title: 'Kırmızı etek', category: 'bottoms', colorName: 'kırmızı', shape: '<path d="M200 100 L400 100 L500 520 L100 520 Z"/>' },
];
for (const g of garments) {
  const img = await svgJpeg(600, 600, `<rect width="100%" height="100%" fill="#ffffff"/><g fill="${g.color}">${g.shape}</g>`);
  await upload(`users/${uid}/garments/${g.id}/original.jpg`, img);
  await upload(`users/${uid}/garments/${g.id}/thumb.jpg`, await sharp(img).resize(240).jpeg().toBuffer());
  await db.doc(FP.garment(uid, g.id)).set({
    status: 'ready',
    storagePath: `users/${uid}/garments/${g.id}/original.jpg`,
    thumbPath: `users/${uid}/garments/${g.id}/thumb.jpg`,
    analysis: {
      isGarment: true,
      category: g.category,
      garmentPhotoType: 'flat-lay',
      dominantColorHex: g.color,
      colorNameTr: g.colorName,
      fabricGuess: 'pamuklu',
      titleTr: g.title,
      descriptionTr: 'Seed verisi.',
      isIsolated: true,
      confidence: 0.9,
    },
    tryonSupported: true,
    userEdited: false,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
}

console.log(`✔ Seed tamam. Giriş: ${EMAIL} / ${PASSWORD} (uid ${uid}, 50 kredi, yönetici)`);
process.exit(0);
