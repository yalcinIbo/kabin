import { JobError, notConfigured } from '../../lib/job_error.js';
import { type FalFile, type FalLike, createFal, falRun, falUpload, fetchImage } from '../fal.js';
import type { TryOnInput, TryOnOutput, TryOnProvider } from '../types.js';

export const FASHN_ENDPOINT = 'fal-ai/fashn/tryon/v1.6';
export const FASHN_COST_PER_IMAGE_USD = 0.075;

/** fal.ai üzerindeki FASHN v1.6. Düz çekim (flat-lay) ve üzerinde giyilmiş kıyafet fotoğraflarını kabul eder. */
export class FashnTryOnProvider implements TryOnProvider {
  readonly id = 'fashn';

  constructor(private readonly opts: { falKey: string; client?: FalLike; timeoutMs?: number }) {}

  get available(): boolean {
    return Boolean(this.opts.client ?? this.opts.falKey);
  }

  buildInput(input: TryOnInput, modelUrl: string, garmentUrl: string): Record<string, unknown> {
    return {
      model_image: modelUrl,
      garment_image: garmentUrl,
      category: input.category,
      garment_photo_type: input.garmentPhotoType,
      mode: input.mode ?? 'balanced',
      num_samples: Math.max(1, Math.min(4, input.numSamples)),
      ...(input.seed !== undefined ? { seed: input.seed } : {}),
      segmentation_free: true,
      moderation_level: 'conservative',
      output_format: 'jpeg',
    };
  }

  async run(input: TryOnInput): Promise<TryOnOutput> {
    if (!this.available) throw notConfigured('FAL_KEY');
    const fal = this.opts.client ?? createFal(this.opts.falKey);
    const started = Date.now();
    const [modelUrl, garmentUrl] = await Promise.all([falUpload(fal, input.person), falUpload(fal, input.garment)]);
    const data = await falRun<{ images?: FalFile[] }>(
      fal,
      FASHN_ENDPOINT,
      this.buildInput(input, modelUrl, garmentUrl),
      'fashn',
      this.opts.timeoutMs ?? 240_000,
    );
    const urls = (data.images ?? []).map((i) => i.url).filter(Boolean);
    if (urls.length === 0) throw new JobError('provider-failed', 'Görsel üretilemedi.', 'fashn: boş sonuç');
    const images = await Promise.all(urls.map((u) => fetchImage(u)));
    return {
      images: images.map((image) => ({ provider: this.id, image })),
      costUsd: FASHN_COST_PER_IMAGE_USD * images.length,
      durationMs: Date.now() - started,
    };
  }
}
