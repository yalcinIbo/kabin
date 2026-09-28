import { notConfigured } from '../../lib/job_error.js';
import { GeminiClient } from '../gemini.js';
import type { TryOnCategory, TryOnInput, TryOnOutput, TryOnProvider } from '../types.js';

export const GEMINI_TRYON_COST_USD = 0.04;

const CATEGORY_TEXT: Record<TryOnCategory, string> = {
  tops: 'upper-body garment (replace only the top; keep trousers/skirt and shoes as they are)',
  bottoms: 'lower-body garment (replace only the trousers/skirt; keep the top and shoes as they are)',
  'one-pieces': 'full-body garment such as a dress or jumpsuit (replace the outfit it covers)',
  auto: 'garment (replace the matching part of the outfit)',
};

export function geminiTryOnPrompt(category: TryOnCategory): string {
  return `Image 1 is a photo of a person. Image 2 is a photo of a clothing item (it may be laid flat, on a hanger, on a model or a screenshot).
Dress the person from image 1 in the ${CATEGORY_TEXT[category]} from image 2.
Reproduce the garment faithfully: same color, pattern, print, fabric texture, neckline, sleeves, length and cut, fitted naturally to the person's body and pose with realistic folds and shadows.
Keep the person's face, hair, skin tone, body shape, pose, background, lighting and camera framing exactly the same. Full body stays in frame.
Photorealistic result. No text, no watermark, no extra people or objects.`;
}

/** Gemini görsel modeliyle giydirme: fal.ai anahtarı olmadan tek Google anahtarıyla çalışan alternatif. */
export class GeminiTryOnProvider implements TryOnProvider {
  readonly id = 'gemini';
  private client: GeminiClient | null = null;

  constructor(private readonly opts: { apiKey: string; model: string }) {}

  get available(): boolean {
    return Boolean(this.opts.apiKey);
  }

  async run(input: TryOnInput): Promise<TryOnOutput> {
    if (!this.available) throw notConfigured('GEMINI_API_KEY');
    this.client ??= new GeminiClient(this.opts.apiKey);
    const started = Date.now();
    const count = Math.max(1, Math.min(2, input.numSamples));
    const images = [];
    for (let i = 0; i < count; i++) {
      const image = await this.client.image({
        model: this.opts.model,
        images: [input.person, input.garment],
        text: geminiTryOnPrompt(input.category),
        label: 'gemini-tryon',
        aspectRatio: '3:4',
        ...(input.seed !== undefined ? { seed: input.seed + i } : {}),
      });
      images.push({ provider: this.id, image });
    }
    return { images, costUsd: GEMINI_TRYON_COST_USD * images.length, durationMs: Date.now() - started };
  }
}
