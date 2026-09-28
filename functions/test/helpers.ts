import sharp from 'sharp';
import { db, bucket } from '../src/lib/admin.js';
import { FP } from '../src/lib/paths.js';
import { resetConfigCache } from '../src/config/pricing.js';
import { createFakeProviders, parseMockList, type ProviderConfig } from '../src/providers/factory.js';
import { setProviders } from '../src/providers/registry.js';

export const hasEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST && process.env.FIREBASE_STORAGE_EMULATOR_HOST);

export const testConfig: ProviderConfig = {
  falKey: '',
  geminiKey: '',
  hfToken: '',
  tryon: 'fashn',
  model3d: 'hunyuan',
  segmentation: 'birefnet',
  vertex: { projectId: 'demo-kabin', location: 'us-central1', model: 'virtual-try-on-001' },
  gemini: { visionModel: 'gemini-3.8-flash', imageModel: 'gemini-3.1-flash-image' },
  mock: parseMockList('all'),
};

export function useFakeProviders(): void {
  setProviders(createFakeProviders(), testConfig);
}

export async function makeJpeg(width: number, height: number, color: string): Promise<Buffer> {
  return sharp({ create: { width, height, channels: 3, background: color } })
    .composite([
      {
        input: Buffer.from(
          `<svg width="${width}" height="${height}"><circle cx="${width / 2}" cy="${height / 5}" r="${width / 8}" fill="#f5d0a9"/>` +
            `<rect x="${width / 3}" y="${height / 3}" width="${width / 3}" height="${height / 2}" fill="#374151"/></svg>`,
        ),
      },
    ])
    .jpeg()
    .toBuffer();
}

export async function clearFirestore(): Promise<void> {
  const host = process.env.FIRESTORE_EMULATOR_HOST!;
  const project = process.env.GCLOUD_PROJECT ?? 'demo-kabin';
  await fetch(`http://${host}/emulator/v1/projects/${project}/databases/(default)/documents`, { method: 'DELETE' });
  resetConfigCache();
}

export async function seedUser(uid: string, data: Record<string, unknown> = {}): Promise<void> {
  await db.doc(FP.user(uid)).set({
    displayName: 'Test',
    credits: 10,
    heightCm: 175,
    weightKg: 70,
    bodyType: 'average',
    consent: { kvkkVersion: '2026-09', kvkkAccepted: true, aiTransferAccepted: true },
    ...data,
  });
}

export async function seedPhoto(uid: string, id: string, status = 'ready'): Promise<string> {
  const path = `users/${uid}/photos/${id}/original.jpg`;
  await bucket().file(path).save(await makeJpeg(600, 1000, '#e5e7eb'), { contentType: 'image/jpeg', resumable: false });
  await db.doc(FP.photo(uid, id)).set({ source: 'upload', status, storagePath: path, isDefault: status === 'ready' });
  return path;
}

export async function seedGarment(uid: string, id: string, category = 'tops'): Promise<string> {
  const path = `users/${uid}/garments/${id}/original.jpg`;
  await bucket().file(path).save(await makeJpeg(500, 500, '#1d4ed8'), { contentType: 'image/jpeg', resumable: false });
  await db.doc(FP.garment(uid, id)).set({
    status: 'ready',
    storagePath: path,
    analysis: { category, garmentPhotoType: 'flat-lay', titleTr: 'Mavi tişört', colorNameTr: 'mavi', fabricGuess: 'pamuk' },
    tryonSupported: true,
  });
  return path;
}

export async function credits(uid: string): Promise<number> {
  return ((await db.doc(FP.user(uid)).get()).get('credits') as number) ?? 0;
}
