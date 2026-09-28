import { notConfigured } from '../../lib/job_error.js';
import { normalizeJpeg } from '../../lib/imaging.js';
import { GeminiClient } from '../gemini.js';
import type { ImageBuf, SegmentationProvider } from '../types.js';

export const GEMINI_ISOLATE_PROMPT = `The image shows a clothing item (it may be laid flat, on a hanger, on a mannequin, worn by a person or a screenshot).
Output only that garment, front view, centered on a plain pure white (#FFFFFF) background, filling most of the frame.
Remove the person, hanger, mannequin, hands, props, shadows and any other background.
Keep the garment exactly the same: color, pattern, print, fabric texture, neckline, sleeves, length and cut. Do not add anything. No text, no watermark.`;

/**
 * Gemini görsel modeliyle kıyafeti düz beyaz zemine alır (fal.ai BiRefNet'in ücretsiz alternatifi).
 * Çıktı şeffaf değil, beyaz zeminlidir; Vertex zaten beyaz zemine düzleştirdiği için yeterlidir.
 */
export class GeminiSegmentation implements SegmentationProvider {
  readonly id = 'gemini-isolate';
  private client: GeminiClient | null = null;

  constructor(private readonly opts: { apiKey: string; model: string }) {}

  get available(): boolean {
    return Boolean(this.opts.apiKey);
  }

  async removeBackground(img: ImageBuf): Promise<ImageBuf> {
    if (!this.available) throw notConfigured('GEMINI_API_KEY');
    this.client ??= new GeminiClient(this.opts.apiKey);
    const out = await this.client.image({ model: this.opts.model, images: [img], text: GEMINI_ISOLATE_PROMPT, label: 'gemini-isolate' });
    return normalizeJpeg(out.data);
  }
}
