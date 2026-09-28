import { logger } from 'firebase-functions/logger';
import { FieldValue, db } from '../lib/admin.js';
import { JobError } from '../lib/job_error.js';
import { makeNonMetallic } from '../lib/glb.js';
import { toJpeg } from '../lib/imaging.js';
import { FP, SP } from '../lib/paths.js';
import { loadImage, saveBuffer, saveImage } from '../lib/storage.js';
import { providers } from '../providers/registry.js';
import type { Model3DChoice, ProviderSet } from '../providers/types.js';
import type { JobContext, ProgressFn } from './runner.js';

export interface Model3DJobData {
  tryonId: string;
  sourcePath: string;
  provider: Model3DChoice;
}

export async function processModel3D(ctx: JobContext, progress: ProgressFn, deps: ProviderSet = providers()): Promise<Record<string, unknown>> {
  const { uid, jobId } = ctx;
  const d = ctx.data as Model3DJobData;

  const generator = deps.model3d(d.provider);
  const source = await loadImage(d.sourcePath);
  let input = source;
  let isolatedPath: string | null = null;
  if (generator.needsIsolatedInput) {
    await progress('segment', 0.08);
    input = await deps.segmentation().removeBackground(source);
    isolatedPath = SP.model3dIsolated(uid, jobId);
    await saveImage(isolatedPath, input);
  }

  await progress('generate', 0.25);
  const result = await generator.generate(input);
  if (result.glb.length < 20 || result.glb.readUInt32LE(0) !== 0x46546c67) {
    throw new JobError('provider-failed', '3D model dosyası geçersiz.', 'glb magic hatalı');
  }

  await progress('saving', 0.9);
  let glb = result.glb;
  try {
    glb = makeNonMetallic(result.glb);
  } catch (e) {
    logger.warn('GLB malzemesi düzeltilemedi, orijinal kaydediliyor', { error: String(e) });
  }
  const glbPath = SP.model3dGlb(uid, jobId);
  await saveBuffer(glbPath, glb, 'model/gltf-binary');
  const previewPath = SP.model3dPreview(uid, jobId);
  await saveImage(previewPath, await toJpeg(result.preview ?? input));

  await db
    .doc(FP.tryon(uid, d.tryonId))
    .update({ model3dId: jobId, updatedAt: FieldValue.serverTimestamp() })
    .catch((e) => logger.warn('Try-on belgesine 3D bağlantısı yazılamadı', { error: String(e) }));

  return {
    glbPath,
    previewPath,
    isolatedPath,
    fileSizeBytes: glb.length,
    providerCostUsd: result.costUsd,
    providerDurationMs: result.durationMs,
  };
}
