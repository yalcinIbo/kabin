import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';
import { ref, uploadBytes } from 'firebase/storage';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';
import { hasEmulator } from './helpers.js';

const consent = { kvkkVersion: '2026-09', kvkkAccepted: true, aiTransferAccepted: true };
let env: RulesTestEnvironment;

describe.skipIf(!hasEmulator)('güvenlik kuralları', () => {
  beforeAll(async () => {
    const [fsHost, fsPort] = process.env.FIRESTORE_EMULATOR_HOST!.split(':');
    const [stHost, stPort] = process.env.FIREBASE_STORAGE_EMULATOR_HOST!.split(':');
    env = await initializeTestEnvironment({
      projectId: 'demo-kabin-rules',
      firestore: { host: fsHost!, port: Number(fsPort), rules: readFileSync(resolve(__dirname, '../../firestore.rules'), 'utf8') },
      storage: { host: stHost!, port: Number(stPort), rules: readFileSync(resolve(__dirname, '../../storage.rules'), 'utf8') },
    });
  });
  beforeEach(async () => {
    await env.clearFirestore();
  });
  afterAll(async () => {
    await env?.cleanup();
  });

  const seed = async (path: string, data: Record<string, unknown>) =>
    env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), path), data);
    });

  it('profil yalnızca 0 kredi ve açık rıza ile oluşturulur', async () => {
    const db = env.authenticatedContext('u1').firestore();
    await assertFails(setDoc(doc(db, 'users/u1'), { credits: 100, consent }));
    await assertFails(setDoc(doc(db, 'users/u1'), { credits: 0, consent: { ...consent, aiTransferAccepted: false } }));
    await assertFails(setDoc(doc(db, 'users/u2'), { credits: 0, consent }));
    await assertFails(setDoc(doc(db, 'users/u1'), { credits: 0, consent, heightCm: 900 }));
    await assertSucceeds(setDoc(doc(db, 'users/u1'), { credits: 0, consent, displayName: 'Ayşe', heightCm: 168 }));
  });

  it('istemci krediyi ve admin bayrağını değiştiremez, ölçüleri güncelleyebilir', async () => {
    await seed('users/u1', { credits: 3, consent });
    const db = env.authenticatedContext('u1').firestore();
    await assertFails(updateDoc(doc(db, 'users/u1'), { credits: 999 }));
    await assertFails(updateDoc(doc(db, 'users/u1'), { isAdmin: true }));
    await assertSucceeds(updateDoc(doc(db, 'users/u1'), { weightKg: 72, bodyType: 'athletic' }));
  });

  it('başka kullanıcının verisi okunamaz', async () => {
    await seed('users/u1', { credits: 3, consent });
    await seed('users/u1/tryons/j1', { status: 'done' });
    const other = env.authenticatedContext('u2').firestore();
    await assertFails(getDoc(doc(other, 'users/u1')));
    await assertFails(getDoc(doc(other, 'users/u1/tryons/j1')));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'users/u1')));
  });

  it('fotoğraf yalnızca pending/upload olarak ve kendi yoluyla oluşturulur', async () => {
    const db = env.authenticatedContext('u1').firestore();
    const ok = { source: 'upload', status: 'pending', storagePath: 'users/u1/photos/p1/original.jpg', isDefault: false };
    await assertFails(setDoc(doc(db, 'users/u1/photos/p1'), { ...ok, status: 'ready' }));
    await assertFails(setDoc(doc(db, 'users/u1/photos/p1'), { ...ok, source: 'generated' }));
    await assertFails(setDoc(doc(db, 'users/u1/photos/p1'), { ...ok, storagePath: 'users/u2/photos/p1/a.jpg' }));
    await assertFails(setDoc(doc(db, 'users/u1/photos/p1'), { ...ok, qc: { passed: true } }));
    await assertSucceeds(setDoc(doc(db, 'users/u1/photos/p1'), ok));
  });

  it('iş, defter ve kullanım belgeleri istemciden yazılamaz; aktif iş silinemez', async () => {
    await seed('users/u1/tryons/j1', { status: 'processing' });
    await seed('users/u1/tryons/j2', { status: 'done' });
    const db = env.authenticatedContext('u1').firestore();
    await assertFails(setDoc(doc(db, 'users/u1/tryons/j3'), { status: 'queued' }));
    await assertFails(updateDoc(doc(db, 'users/u1/tryons/j2'), { status: 'queued' }));
    await assertFails(setDoc(doc(db, 'users/u1/ledger/x'), { amount: 100 }));
    await assertFails(setDoc(doc(db, 'users/u1/usage/20260925'), { tryon: 0 }));
    await assertFails(deleteDoc(doc(db, 'users/u1/tryons/j1')));
    await assertSucceeds(deleteDoc(doc(db, 'users/u1/tryons/j2')));
  });

  it('kıyafet analizi yalnızca izinli alanlarla düzeltilebilir', async () => {
    await seed('users/u1/garments/g1', { status: 'ready', storagePath: 'users/u1/garments/g1/original.jpg', analysis: { category: 'tops' } });
    const db = env.authenticatedContext('u1').firestore();
    const analysis = { category: 'dresses', garmentPhotoType: 'flat-lay', titleTr: 'Yazlık elbise', colorNameTr: 'beyaz' };
    await assertSucceeds(updateDoc(doc(db, 'users/u1/garments/g1'), { analysis, userEdited: true }));
    await assertFails(updateDoc(doc(db, 'users/u1/garments/g1'), { analysis: { ...analysis, category: 'uçak' } }));
    await assertFails(updateDoc(doc(db, 'users/u1/garments/g1'), { isolatedPath: 'x' }));
  });

  it('benchmark yalnızca yönetici tarafından okunur ve puanlanır', async () => {
    await seed('benchmarks/r1/pairs/p1', { status: 'done' });
    await assertFails(getDoc(doc(env.authenticatedContext('u1').firestore(), 'benchmarks/r1/pairs/p1')));
    const admin = env.authenticatedContext('a1', { admin: true }).firestore();
    await assertSucceeds(getDoc(doc(admin, 'benchmarks/r1/pairs/p1')));
    await assertSucceeds(updateDoc(doc(admin, 'benchmarks/r1/pairs/p1'), { rating: { winner: 'fashn' } }));
    await assertFails(updateDoc(doc(admin, 'benchmarks/r1/pairs/p1'), { status: 'queued' }));
  });

  it('Storage: ham görseller yalnız sahibine, sonuçlar istemciden yazılamaz', async () => {
    const img = new Uint8Array([0xff, 0xd8, 0xff, 0xe0]);
    const meta = { contentType: 'image/jpeg' };
    const mine = env.authenticatedContext('u1').storage();
    await assertSucceeds(uploadBytes(ref(mine, 'users/u1/photos/p1/original.jpg'), img, meta));
    await assertFails(uploadBytes(ref(mine, 'users/u2/photos/p1/original.jpg'), img, meta));
    await assertFails(uploadBytes(ref(mine, 'users/u1/tryons/j1/front.jpg'), img, meta));
    await assertFails(uploadBytes(ref(mine, 'users/u1/photos/p1/virus.exe'), img, { contentType: 'application/octet-stream' }));
  });
});
