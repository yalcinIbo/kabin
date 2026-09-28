import { FieldValue } from '../lib/admin.js';
import { JobError } from '../lib/job_error.js';
import { imageSize, thumbnail, toJpeg } from '../lib/imaging.js';
import { SP } from '../lib/paths.js';
import { deleteFileQuietly, loadImage, saveImage } from '../lib/storage.js';
import type { PhotoQc } from '../ai/schemas.js';
import { providers } from '../providers/registry.js';
import type { AvatarParams, ImageBuf, ProviderSet } from '../providers/types.js';
import { hasNoDefaultPhoto } from './defaults.js';
import type { JobContext, ProgressFn } from './runner.js';

export interface AvatarJobData {
  avatarParams: AvatarParams & { selfiePath: string };
}

export async function processAvatar(ctx: JobContext, progress: ProgressFn, deps: ProviderSet = providers()): Promise<Record<string, unknown>> {
  const { uid, jobId } = ctx;
  const { selfiePath, ...params } = (ctx.data as AvatarJobData).avatarParams;

  await progress('checking', 0.08);
  const selfie = await loadImage(selfiePath);
  const selfieQc = await deps.vision().checkSelfie(selfie);
  if (!selfieQc.passed) {
    throw new JobError(selfieQc.blocked ? 'content-blocked' : 'quality-check-failed', selfieQc.hintTr);
  }

  let accepted: { image: ImageBuf; qc: PhotoQc } | null = null;
  for (let attempt = 0; attempt < 2 && !accepted; attempt++) {
    await progress('generating', 0.25 + attempt * 0.3);
    const image = await deps.avatar().generateStudioAvatar(selfie, params, attempt);
    await progress('verifying', 0.45 + attempt * 0.3);
    const qc = await deps.vision().checkPhoto(image);
    if (qc.blocked) throw new JobError('content-blocked', 'Görsel güvenlik denetiminden geçemedi.');
    if (qc.passed) accepted = { image, qc };
  }
  if (!accepted) {
    throw new JobError(
      'quality-check-failed',
      'Stüdyo fotoğrafı istenen kalitede üretilemedi. Farklı bir selfie ile tekrar deneyebilirsin.',
    );
  }

  await progress('saving', 0.92);
  const image = await toJpeg(accepted.image);
  const storagePath = SP.photoStudio(uid, jobId);
  const thumbPath = SP.photoThumb(uid, jobId);
  await saveImage(storagePath, image);
  await saveImage(thumbPath, await thumbnail(image));
  const size = await imageSize(image);
  const isDefault = await hasNoDefaultPhoto(uid);
  await deleteFileQuietly(selfiePath);

  return {
    storagePath,
    thumbPath,
    ...size,
    isDefault,
    qc: { ...accepted.qc, checkedAt: FieldValue.serverTimestamp() },
  };
}
