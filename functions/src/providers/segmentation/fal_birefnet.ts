import { notConfigured } from '../../lib/job_error.js';
import { normalizePng } from '../../lib/imaging.js';
import { type FalFile, type FalLike, createFal, falRun, falUpload, fetchImage } from '../fal.js';
import type { ImageBuf, SegmentationProvider } from '../types.js';

export const BIREFNET_ENDPOINT = 'fal-ai/birefnet';

/** fal.ai BiRefNet ile arka plan silme; alfa kanallı PNG döner. */
export class FalBirefnetSegmentation implements SegmentationProvider {
  readonly id = 'birefnet';

  constructor(private readonly opts: { falKey: string; client?: FalLike }) {}

  get available(): boolean {
    return Boolean(this.opts.client ?? this.opts.falKey);
  }

  async removeBackground(img: ImageBuf): Promise<ImageBuf> {
    if (!this.available) throw notConfigured('FAL_KEY');
    const fal = this.opts.client ?? createFal(this.opts.falKey);
    const url = await falUpload(fal, img);
    const data = await falRun<{ image: FalFile }>(
      fal,
      BIREFNET_ENDPOINT,
      { image_url: url, model: 'General Use (Light)', operating_resolution: '1024x1024', output_format: 'png', refine_foreground: true },
      'birefnet',
      90_000,
    );
    const out = await fetchImage(data.image.url);
    return normalizePng(out.data);
  }
}
