import { JobError, notConfigured } from '../../lib/job_error.js';
import { type FalFile, type FalLike, createFal, falRun, falUpload, fetchBinary } from '../fal.js';
import type { ImageBuf, Model3DProvider, Model3DResult } from '../types.js';

export const HUNYUAN_ENDPOINT = 'fal-ai/hunyuan3d/v2';

/** fal.ai Hunyuan3D v2 (dokulu mesh). 1-3 dk sürebilir. */
export class FalHunyuan3DProvider implements Model3DProvider {
  readonly id = 'hunyuan';
  readonly needsIsolatedInput = true;

  constructor(private readonly opts: { falKey: string; client?: FalLike; textured?: boolean }) {}

  get available(): boolean {
    return Boolean(this.opts.client ?? this.opts.falKey);
  }

  async generate(img: ImageBuf): Promise<Model3DResult> {
    if (!this.available) throw notConfigured('FAL_KEY');
    const fal = this.opts.client ?? createFal(this.opts.falKey);
    const started = Date.now();
    const textured = this.opts.textured ?? true;
    const url = await falUpload(fal, img);
    const data = await falRun<{ model_mesh?: FalFile }>(
      fal,
      HUNYUAN_ENDPOINT,
      { input_image_url: url, textured_mesh: textured },
      'hunyuan3d',
      420_000,
    );
    if (!data.model_mesh?.url) throw new JobError('provider-failed', '3D model üretilemedi.', 'hunyuan: model_mesh yok');
    const { data: glb } = await fetchBinary(data.model_mesh.url, 120_000);
    return { glb, costUsd: textured ? 0.48 : 0.16, durationMs: Date.now() - started };
  }
}
