import { JobError, notConfigured } from '../../lib/job_error.js';
import { type FalFile, type FalLike, createFal, falRun, falUpload, fetchBinary, fetchImage } from '../fal.js';
import type { ImageBuf, Model3DProvider, Model3DResult } from '../types.js';

export const TRIPO_ENDPOINT = 'tripo3d/tripo/v2.5/image-to-3d';

/** fal.ai Tripo v2.5 (PBR dokulu). */
export class FalTripo3DProvider implements Model3DProvider {
  readonly id = 'tripo';
  readonly needsIsolatedInput = true;

  constructor(private readonly opts: { falKey: string; client?: FalLike }) {}

  get available(): boolean {
    return Boolean(this.opts.client ?? this.opts.falKey);
  }

  async generate(img: ImageBuf): Promise<Model3DResult> {
    if (!this.available) throw notConfigured('FAL_KEY');
    const fal = this.opts.client ?? createFal(this.opts.falKey);
    const started = Date.now();
    const url = await falUpload(fal, img);
    const data = await falRun<{ model_mesh?: FalFile; pbr_model?: FalFile; rendered_image?: FalFile }>(
      fal,
      TRIPO_ENDPOINT,
      { image_url: url, texture: 'standard', pbr: true, texture_alignment: 'original_image', face_limit: 60000 },
      'tripo3d',
      420_000,
    );
    const meshUrl = data.pbr_model?.url ?? data.model_mesh?.url;
    if (!meshUrl) throw new JobError('provider-failed', '3D model üretilemedi.', 'tripo: model yok');
    const [{ data: glb }, preview] = await Promise.all([
      fetchBinary(meshUrl, 120_000),
      data.rendered_image?.url ? fetchImage(data.rendered_image.url).catch(() => undefined) : Promise.resolve(undefined),
    ]);
    return { glb, ...(preview ? { preview } : {}), costUsd: 0.3, durationMs: Date.now() - started };
  }
}
