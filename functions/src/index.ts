import * as functionsV1 from 'firebase-functions/v1';
import { setGlobalOptions } from 'firebase-functions/v2';
import { onDocumentCreated, onDocumentDeleted } from 'firebase-functions/v2/firestore';
import { type CallableRequest, onCall } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { db } from './lib/admin.js';
import { httpsError } from './lib/https.js';
import { FP, SP } from './lib/paths.js';
import { deletePrefix } from './lib/storage.js';
import { AI_SECRETS } from './config/params.js';
import { deleteMyAccountHandler, purgeUserData } from './callables/account.js';
import { analyzeGarmentHandler } from './callables/analyze_garment.js';
import { processBenchmarkPair, runBenchmarkHandler } from './callables/benchmark.js';
import { checkPhotoHandler } from './callables/check_photo.js';
import type { Caller } from './callables/common.js';
import { generateAvatarHandler } from './callables/generate_avatar.js';
import { requestModel3DHandler } from './callables/request_model3d.js';
import { requestTryOnHandler } from './callables/request_tryon.js';
import { processAvatar } from './jobs/avatar_pipeline.js';
import { processModel3D } from './jobs/model3d_pipeline.js';
import { runJob } from './jobs/runner.js';
import { sweepStuckJobs } from './jobs/sweeper.js';
import { processTryOn } from './jobs/tryon_pipeline.js';
import { grantWelcomeCredits } from './triggers/welcome.js';

const REGION = 'europe-west1';
setGlobalOptions({ region: REGION, maxInstances: 10 });

function caller(req: CallableRequest<unknown>): Caller {
  if (!req.auth) throw httpsError('unauthenticated', 'Devam etmek için giriş yapmalısın.', 'unauthenticated');
  const token = req.auth.token as Record<string, unknown>;
  return {
    uid: req.auth.uid,
    isAdmin: token.admin === true,
    authTime: typeof token.auth_time === 'number' ? token.auth_time : undefined,
  };
}

// ---------------------------------------------------------------- callables
export const checkPhoto = onCall({ secrets: AI_SECRETS, timeoutSeconds: 90, memory: '512MiB' }, (req) =>
  checkPhotoHandler(caller(req), req.data),
);
export const analyzeGarment = onCall({ secrets: AI_SECRETS, timeoutSeconds: 90, memory: '512MiB' }, (req) =>
  analyzeGarmentHandler(caller(req), req.data),
);
export const requestTryOn = onCall({ timeoutSeconds: 30 }, (req) => requestTryOnHandler(caller(req), req.data));
export const requestModel3D = onCall({ timeoutSeconds: 30 }, (req) => requestModel3DHandler(caller(req), req.data));
export const generateAvatar = onCall({ timeoutSeconds: 30 }, (req) => generateAvatarHandler(caller(req), req.data));
export const deleteMyAccount = onCall({ timeoutSeconds: 300, memory: '512MiB' }, (req) => deleteMyAccountHandler(caller(req)));
export const runBenchmark = onCall({ timeoutSeconds: 60 }, (req) => runBenchmarkHandler(caller(req), req.data));

// ---------------------------------------------------------------- iş tetikleyicileri
const JOB_OPTS = { timeoutSeconds: 540, memory: '1GiB' as const, secrets: AI_SECRETS, retry: false };
const LEASE_MS = 9 * 60_000 + 30_000;

export const onUserCreated = onDocumentCreated('users/{uid}', (e) => grantWelcomeCredits(e.params.uid));

export const onTryOnCreated = onDocumentCreated({ document: 'users/{uid}/tryons/{jobId}', ...JOB_OPTS }, async (e) => {
  if (!e.data) return;
  await runJob({ kind: 'tryon', uid: e.params.uid, jobId: e.params.jobId, ref: e.data.ref, leaseMs: LEASE_MS, work: (ctx, p) => processTryOn(ctx, p) });
});

export const onModel3DCreated = onDocumentCreated({ document: 'users/{uid}/models3d/{modelId}', ...JOB_OPTS }, async (e) => {
  if (!e.data) return;
  await runJob({ kind: 'model3d', uid: e.params.uid, jobId: e.params.modelId, ref: e.data.ref, leaseMs: LEASE_MS, work: (ctx, p) => processModel3D(ctx, p) });
});

export const onPhotoCreated = onDocumentCreated({ document: 'users/{uid}/photos/{photoId}', ...JOB_OPTS }, async (e) => {
  if (!e.data || e.data.get('source') !== 'generated') return;
  await runJob({ kind: 'avatar', uid: e.params.uid, jobId: e.params.photoId, ref: e.data.ref, leaseMs: LEASE_MS, work: (ctx, p) => processAvatar(ctx, p) });
});

export const onBenchmarkPairCreated = onDocumentCreated({ document: 'benchmarks/{runId}/pairs/{pairId}', ...JOB_OPTS }, async (e) => {
  if (!e.data) return;
  await processBenchmarkPair(e.params.runId, e.data.ref);
});

// ---------------------------------------------------------------- Storage temizliği
export const onPhotoDeleted = onDocumentDeleted('users/{uid}/photos/{id}', (e) => deletePrefix(SP.photoDir(e.params.uid, e.params.id)));
export const onGarmentDeleted = onDocumentDeleted('users/{uid}/garments/{id}', (e) => deletePrefix(SP.garmentDir(e.params.uid, e.params.id)));
export const onTryOnDeleted = onDocumentDeleted('users/{uid}/tryons/{id}', (e) => deletePrefix(SP.tryonDir(e.params.uid, e.params.id)));
export const onModel3DDeleted = onDocumentDeleted('users/{uid}/models3d/{id}', async (e) => {
  await deletePrefix(SP.model3dDir(e.params.uid, e.params.id));
  const tryonId = e.data?.get('tryonId') as string | undefined;
  if (tryonId) {
    await db
      .doc(FP.tryon(e.params.uid, tryonId))
      .update({ model3dId: null, model3dRequestId: null })
      .catch(() => undefined);
  }
});

// ---------------------------------------------------------------- bakım
export const sweepJobs = onSchedule({ schedule: 'every 10 minutes', timeZone: 'Europe/Istanbul', timeoutSeconds: 300 }, async () => {
  await sweepStuckJobs();
});

/** Konsoldan silinen hesaplar için emniyet kemeri. */
export const onAuthUserDeleted = functionsV1.region(REGION).auth.user().onDelete((user) => purgeUserData(user.uid));
