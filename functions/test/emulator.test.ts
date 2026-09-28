import { Timestamp } from 'firebase-admin/firestore';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { db, bucket } from '../src/lib/admin.js';
import { FP } from '../src/lib/paths.js';
import { parseGlb } from '../src/lib/glb.js';
import { dayKey } from '../src/lib/time.js';
import { requestTryOnHandler } from '../src/callables/request_tryon.js';
import { requestModel3DHandler } from '../src/callables/request_model3d.js';
import { checkPhotoHandler } from '../src/callables/check_photo.js';
import { analyzeGarmentHandler } from '../src/callables/analyze_garment.js';
import { generateAvatarHandler } from '../src/callables/generate_avatar.js';
import { deleteMyAccountHandler } from '../src/callables/account.js';
import { processBenchmarkPair, runBenchmarkHandler } from '../src/callables/benchmark.js';
import { grantWelcomeCredits } from '../src/triggers/welcome.js';
import { refundJob } from '../src/credits/ledger.js';
import { runJob } from '../src/jobs/runner.js';
import { processTryOn } from '../src/jobs/tryon_pipeline.js';
import { processModel3D } from '../src/jobs/model3d_pipeline.js';
import { processAvatar } from '../src/jobs/avatar_pipeline.js';
import { sweepStuckJobs } from '../src/jobs/sweeper.js';
import { JobError } from '../src/lib/job_error.js';
import { createFakeProviders } from '../src/providers/factory.js';
import { setProviders } from '../src/providers/registry.js';
import type { ProviderSet } from '../src/providers/types.js';
import { clearFirestore, credits, hasEmulator, makeJpeg, seedGarment, seedPhoto, seedUser, testConfig, useFakeProviders } from './helpers.js';

const me = (uid: string, extra: Partial<{ isAdmin: boolean; authTime: number }> = {}) => ({ uid, isAdmin: false, ...extra });
const LEASE = 60_000;

describe.skipIf(!hasEmulator)('emülatör: kredi, iş akışı ve iade', () => {
  beforeAll(() => useFakeProviders());
  beforeEach(async () => {
    await clearFirestore();
    useFakeProviders();
  });
  afterAll(() => setProviders(null));

  it('hoş geldin kredisini yalnızca bir kez verir', async () => {
    await seedUser('u1', { credits: 0 });
    expect(await grantWelcomeCredits('u1')).toBe(true);
    expect(await grantWelcomeCredits('u1')).toBe(false);
    expect(await credits('u1')).toBe(10);
    const ledger = await db.doc(FP.ledgerEntry('u1', 'welcome')).get();
    expect(ledger.get('amount')).toBe(10);
  });

  it('yetersiz krediyi Türkçe hata ile reddeder', async () => {
    await seedUser('u1', { credits: 1 });
    await seedPhoto('u1', 'p1');
    await seedGarment('u1', 'g1');
    await expect(requestTryOnHandler(me('u1'), { photoId: 'p1', garmentId: 'g1', multiView: true })).rejects.toMatchObject({
      code: 'resource-exhausted',
      details: { reason: 'insufficient-credits', required: 2 },
    });
    expect(await credits('u1')).toBe(1);
  });

  it('günlük sınırı uygular', async () => {
    await seedUser('u1', { credits: 50 });
    await seedPhoto('u1', 'p1');
    await seedGarment('u1', 'g1');
    await db.doc(FP.pricing).set({ dailyCaps: { tryon: 1 } });
    await requestTryOnHandler(me('u1'), { photoId: 'p1', garmentId: 'g1', multiView: false });
    await expect(requestTryOnHandler(me('u1'), { photoId: 'p1', garmentId: 'g1', multiView: false })).rejects.toMatchObject({
      details: { reason: 'daily-cap' },
    });
  });

  it('desteklenmeyen kategoriyi ve yönetici olmayan sağlayıcı seçimini reddeder', async () => {
    await seedUser('u1');
    await seedPhoto('u1', 'p1');
    await seedGarment('u1', 'g1', 'shoes');
    await expect(requestTryOnHandler(me('u1'), { photoId: 'p1', garmentId: 'g1' })).rejects.toMatchObject({
      details: { reason: 'unsupported-category' },
    });
    await expect(requestTryOnHandler(me('u1'), { photoId: 'p1', garmentId: 'g1', provider: 'both' })).rejects.toMatchObject({
      code: 'permission-denied',
    });
  });

  it('uçtan uca: kredi düşer, iş tamamlanır, 3 açı + stil tavsiyesi yazılır', async () => {
    await seedUser('u1', { credits: 10 });
    await seedPhoto('u1', 'p1');
    await seedGarment('u1', 'g1');
    const { jobId, cost, creditsLeft } = await requestTryOnHandler(me('u1'), { photoId: 'p1', garmentId: 'g1', multiView: true });
    expect(cost).toBe(2);
    expect(creditsLeft).toBe(8);
    const ref = db.doc(FP.tryon('u1', jobId));
    expect((await ref.get()).get('status')).toBe('queued');
    expect((await db.doc(FP.ledgerEntry('u1', `debit_${jobId}`)).get()).get('amount')).toBe(-2);
    expect((await db.doc(FP.usage('u1', dayKey())).get()).get('tryon')).toBe(1);

    const outcome = await runJob({ kind: 'tryon', uid: 'u1', jobId, ref, leaseMs: LEASE, work: (c, p) => processTryOn(c, p) });
    expect(outcome).toBe('done');
    const job = (await ref.get()).data()!;
    expect(job.status).toBe('done');
    expect(job.progress).toBe(1);
    expect(job.results.map((r: { angle: string }) => r.angle)).toEqual(['front', 'side', 'back']);
    expect(job.styleAdvice.fitTr).toContain('Mavi tişört');
    const [exists] = await bucket().file(job.results[0].storagePath).exists();
    expect(exists).toBe(true);
    const [meta] = await bucket().file(job.thumbPath).getMetadata();
    expect(meta.metadata?.firebaseStorageDownloadTokens).toBeTruthy();
    expect(await credits('u1')).toBe(8);

    // ikinci teslim işlemez
    expect(await runJob({ kind: 'tryon', uid: 'u1', jobId, ref, leaseMs: LEASE, work: (c, p) => processTryOn(c, p) })).toBe('skipped');
  });

  it('sağlayıcı hatasında işi failed yapar ve krediyi bir kez iade eder', async () => {
    const fakes = createFakeProviders();
    const broken: ProviderSet = {
      ...fakes,
      tryOn: () => ({ id: 'x', available: true, run: async () => { throw new JobError('provider-failed', 'Servis şu anda yoğun.', 'boom'); } }),
    };
    setProviders(broken, testConfig);
    await seedUser('u1', { credits: 5 });
    await seedPhoto('u1', 'p1');
    await seedGarment('u1', 'g1');
    const { jobId } = await requestTryOnHandler(me('u1'), { photoId: 'p1', garmentId: 'g1', multiView: true });
    const ref = db.doc(FP.tryon('u1', jobId));
    expect(await credits('u1')).toBe(3);
    expect(await runJob({ kind: 'tryon', uid: 'u1', jobId, ref, leaseMs: LEASE, work: (c, p) => processTryOn(c, p, broken) })).toBe('failed');
    const job = (await ref.get()).data()!;
    expect(job.status).toBe('failed');
    expect(job.error).toEqual({ code: 'provider-failed', messageTr: 'Servis şu anda yoğun.' });
    expect(job.refunded).toBe(true);
    expect(await credits('u1')).toBe(5);
    expect((await db.doc(FP.usage('u1', dayKey())).get()).get('tryon')).toBe(0);
    expect(await refundJob({ uid: 'u1', kind: 'tryon', jobId, jobRef: ref })).toBe(0);
    expect(await credits('u1')).toBe(5);
  });

  it('çoklu açı tamamen başarısızsa yalnızca o kısmı iade eder', async () => {
    const fakes = createFakeProviders();
    const noViews: ProviderSet = {
      ...fakes,
      multiView: () => ({ id: 'v', available: true, generateView: async () => { throw new Error('no'); } }),
    };
    await seedUser('u1', { credits: 5 });
    await seedPhoto('u1', 'p1');
    await seedGarment('u1', 'g1');
    const { jobId } = await requestTryOnHandler(me('u1'), { photoId: 'p1', garmentId: 'g1', multiView: true });
    const ref = db.doc(FP.tryon('u1', jobId));
    expect(await runJob({ kind: 'tryon', uid: 'u1', jobId, ref, leaseMs: LEASE, work: (c, p) => processTryOn(c, p, noViews) })).toBe('done');
    const job = (await ref.get()).data()!;
    expect(job.multiViewFailed).toBe(true);
    expect(job.refundedAmount).toBe(1);
    expect(job.refunded).toBe(false);
    expect(await credits('u1')).toBe(4);
    // ardından tam iade kalan tutarı iade eder
    expect(await refundJob({ uid: 'u1', kind: 'tryon', jobId, jobRef: ref })).toBe(1);
    expect(await credits('u1')).toBe(5);
  });

  it('süpürücü süresi dolan işi iade eder', async () => {
    await seedUser('u1', { credits: 5 });
    await seedPhoto('u1', 'p1');
    await seedGarment('u1', 'g1');
    const { jobId } = await requestTryOnHandler(me('u1'), { photoId: 'p1', garmentId: 'g1', multiView: false });
    const ref = db.doc(FP.tryon('u1', jobId));
    await ref.update({ leaseUntil: Timestamp.fromMillis(Date.now() - 1000) });
    expect(await sweepStuckJobs()).toBe(1);
    expect((await ref.get()).get('status')).toBe('failed');
    expect((await ref.get()).get('error.code')).toBe('timeout');
    expect(await credits('u1')).toBe(5);
    expect(await sweepStuckJobs()).toBe(0);
  });

  it('3D model varsayılan olarak kapalıdır; kredi düşmez', async () => {
    await seedUser('u1', { credits: 20 });
    await seedPhoto('u1', 'p1');
    await seedGarment('u1', 'g1');
    const { jobId } = await requestTryOnHandler(me('u1'), { photoId: 'p1', garmentId: 'g1', multiView: false });
    await runJob({ kind: 'tryon', uid: 'u1', jobId, ref: db.doc(FP.tryon('u1', jobId)), leaseMs: LEASE, work: (c, p) => processTryOn(c, p) });
    const before = await credits('u1');
    await expect(requestModel3DHandler(me('u1'), { tryonId: jobId })).rejects.toMatchObject({ details: { reason: 'feature-disabled' } });
    expect(await credits('u1')).toBe(before);
  });

  it('3D model işi GLB üretir; aynı deneme için tekrar ücret almaz', async () => {
    await db.doc(FP.flags).set({ model3dEnabled: true });
    await seedUser('u1', { credits: 20 });
    await seedPhoto('u1', 'p1');
    await seedGarment('u1', 'g1');
    const { jobId } = await requestTryOnHandler(me('u1'), { photoId: 'p1', garmentId: 'g1', multiView: false });
    const tryonRef = db.doc(FP.tryon('u1', jobId));
    await runJob({ kind: 'tryon', uid: 'u1', jobId, ref: tryonRef, leaseMs: LEASE, work: (c, p) => processTryOn(c, p) });
    const before = await credits('u1');
    const first = await requestModel3DHandler(me('u1'), { tryonId: jobId });
    expect(first.cost).toBe(5);
    expect(await credits('u1')).toBe(before - 5);
    const again = await requestModel3DHandler(me('u1'), { tryonId: jobId });
    expect(again).toMatchObject({ modelId: first.modelId, cost: 0, existing: true });

    const modelRef = db.doc(FP.model3d('u1', first.modelId));
    expect(await runJob({ kind: 'model3d', uid: 'u1', jobId: first.modelId, ref: modelRef, leaseMs: LEASE, work: (c, p) => processModel3D(c, p) })).toBe('done');
    const model = (await modelRef.get()).data()!;
    const [glb] = await bucket().file(model.glbPath).download();
    expect(parseGlb(glb).version).toBe(2);
    expect((await tryonRef.get()).get('model3dId')).toBe(first.modelId);
  });

  it('fotoğraf kalite kontrolü ve kıyafet analizi belgeleri günceller', async () => {
    await seedUser('u1');
    await seedPhoto('u1', 'p1', 'pending');
    await db.doc(FP.photo('u1', 'p1')).update({ isDefault: false });
    const qc = await checkPhotoHandler(me('u1'), { photoId: 'p1' });
    expect(qc).toMatchObject({ status: 'ready', isDefault: true });
    expect((await db.doc(FP.photo('u1', 'p1')).get()).get('qc.passed')).toBe(true);

    await seedGarment('u1', 'g1');
    await db.doc(FP.garment('u1', 'g1')).update({ status: 'analyzing', analysis: null });
    const res = await analyzeGarmentHandler(me('u1'), { garmentId: 'g1' });
    expect(res.status).toBe('ready');
    expect(res.analysis?.dominantColorHex).toMatch(/^#[0-9a-f]{6}$/);
    expect((await db.doc(FP.usage('u1', dayKey())).get()).get('analysis')).toBe(2);
  });

  it('avatar: selfie → stüdyo fotoğrafı, geçici selfie silinir', async () => {
    await seedUser('u1', { credits: 3 });
    const selfiePath = 'users/u1/tmp/selfie1.jpg';
    await bucket().file(selfiePath).save(await makeJpeg(400, 400, '#fde68a'), { contentType: 'image/jpeg', resumable: false });
    await expect(generateAvatarHandler(me('u1'), { selfiePath: 'users/u2/tmp/x.jpg', heightCm: 170, weightKg: 60, bodyType: 'slim' })).rejects.toMatchObject({
      code: 'permission-denied',
    });
    const { photoId, creditsLeft } = await generateAvatarHandler(me('u1'), { selfiePath, heightCm: 170, weightKg: 60, bodyType: 'slim', gender: 'female' });
    expect(creditsLeft).toBe(2);
    const ref = db.doc(FP.photo('u1', photoId));
    expect(await runJob({ kind: 'avatar', uid: 'u1', jobId: photoId, ref, leaseMs: LEASE, work: (c, p) => processAvatar(c, p) })).toBe('done');
    const photo = (await ref.get()).data()!;
    expect(photo.status).toBe('ready');
    expect(photo.isDefault).toBe(true);
    expect((await bucket().file(photo.storagePath).exists())[0]).toBe(true);
    expect((await bucket().file(selfiePath).exists())[0]).toBe(false);
  });

  it('benchmark: yönetici koşusu her sağlayıcı için sonuç yazar', async () => {
    await seedUser('admin');
    await seedPhoto('admin', 'p1');
    await seedGarment('admin', 'g1');
    await seedGarment('admin', 'g2', 'bottoms');
    await expect(runBenchmarkHandler(me('admin'), { photoId: 'p1', garmentIds: ['g1'] })).rejects.toMatchObject({ code: 'permission-denied' });
    const { runId, pairCount } = await runBenchmarkHandler(me('admin', { isAdmin: true }), { photoId: 'p1', garmentIds: ['g1', 'g2'] });
    expect(pairCount).toBe(2);
    const pairRef = db.doc(FP.benchmarkPair(runId, 'g1'));
    await processBenchmarkPair(runId, pairRef);
    const pair = (await pairRef.get()).data()!;
    expect(pair.status).toBe('done');
    expect(Object.keys(pair.results).sort()).toEqual(['fashn', 'vertex']);
    expect(pair.results.fashn.storagePath).toContain(`benchmarks/${runId}/g1/fashn.jpg`);
    expect((await db.doc(FP.benchmark(runId)).get()).get('doneCount')).toBe(1);
  });

  it('hesap silme yeniden giriş ister ve tüm verileri siler', async () => {
    await seedUser('u1');
    await seedPhoto('u1', 'p1');
    await expect(deleteMyAccountHandler(me('u1', { authTime: 1 }))).rejects.toMatchObject({ details: { reason: 'requires-recent-login' } });
    await deleteMyAccountHandler(me('u1', { authTime: Math.floor(Date.now() / 1000) }));
    expect((await db.doc(FP.user('u1')).get()).exists).toBe(false);
    expect((await db.doc(FP.photo('u1', 'p1')).get()).exists).toBe(false);
    const [files] = await bucket().getFiles({ prefix: 'users/u1/' });
    expect(files).toHaveLength(0);
  });
});
