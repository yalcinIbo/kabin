import { notConfigured } from '../../lib/job_error.js';
import { multiViewPrompt, studioAvatarPrompt } from '../../ai/prompts.js';
import { GeminiClient } from '../gemini.js';
import type { AvatarParams, AvatarProvider, ImageBuf, MultiViewProvider, ViewAngle } from '../types.js';

export const GEMINI_IMAGE_COST_USD = 0.04;

/** Gemini görsel modeli (Nano Banana 2): çoklu açı ve stüdyo avatar üretimi. */
export class GeminiImageProvider implements MultiViewProvider, AvatarProvider {
  readonly id = 'gemini-image';
  private client: GeminiClient | null = null;

  constructor(private readonly opts: { apiKey: string; model: string }) {}

  get available(): boolean {
    return Boolean(this.opts.apiKey);
  }

  private gemini(): GeminiClient {
    if (!this.available) throw notConfigured('GEMINI_API_KEY');
    this.client ??= new GeminiClient(this.opts.apiKey);
    return this.client;
  }

  generateView(front: ImageBuf, angle: ViewAngle): Promise<ImageBuf> {
    return this.gemini().image({
      model: this.opts.model,
      images: [front],
      text: multiViewPrompt(angle),
      label: `gemini-view-${angle}`,
      aspectRatio: '3:4',
    });
  }

  generateStudioAvatar(selfie: ImageBuf, params: AvatarParams, attempt: number): Promise<ImageBuf> {
    return this.gemini().image({
      model: this.opts.model,
      images: [selfie],
      text: studioAvatarPrompt(params, attempt),
      label: 'gemini-avatar',
      aspectRatio: '3:4',
      seed: 1000 + attempt * 7919,
    });
  }
}
