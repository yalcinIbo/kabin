import { notConfigured } from '../../lib/job_error.js';
import {
  GARMENT_SYSTEM,
  PHOTO_QC_SYSTEM,
  SELFIE_QC_SYSTEM,
  STYLE_SYSTEM,
  photoQcUserText,
  styleUserText,
} from '../../ai/prompts.js';
import {
  GarmentAnalysisSchema,
  PhotoQcSchema,
  SelfieQcSchema,
  StyleAdviceSchema,
  finalizeGarment,
  finalizePhotoQc,
  finalizeSelfieQc,
  finalizeStyleAdvice,
  type GarmentAnalysis,
  type PhotoQc,
  type SelfieQc,
  type StyleAdvice,
} from '../../ai/schemas.js';
import { GeminiClient } from '../gemini.js';
import type { ImageBuf, StyleContext, VisionAnalyzer } from '../types.js';

/** Gemini görsel anlama: fotoğraf kalite kontrolü, kıyafet analizi, stil tavsiyesi. */
export class GeminiVisionAnalyzer implements VisionAnalyzer {
  readonly id = 'gemini-vision';
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

  async checkPhoto(img: ImageBuf): Promise<PhotoQc> {
    const raw = await this.gemini().json({
      model: this.opts.model,
      system: PHOTO_QC_SYSTEM,
      images: [img],
      text: photoQcUserText(),
      schema: PhotoQcSchema,
      label: 'photo-qc',
    });
    return finalizePhotoQc(raw);
  }

  async checkSelfie(img: ImageBuf): Promise<SelfieQc> {
    const raw = await this.gemini().json({
      model: this.opts.model,
      system: SELFIE_QC_SYSTEM,
      images: [img],
      text: 'Check this selfie.',
      schema: SelfieQcSchema,
      label: 'selfie-qc',
    });
    return finalizeSelfieQc(raw);
  }

  async analyzeGarment(img: ImageBuf): Promise<GarmentAnalysis> {
    const raw = await this.gemini().json({
      model: this.opts.model,
      system: GARMENT_SYSTEM,
      images: [img],
      text: 'Analyze this clothing photo.',
      schema: GarmentAnalysisSchema,
      label: 'garment',
    });
    return finalizeGarment(raw);
  }

  async styleAdvice(result: ImageBuf, ctx: StyleContext): Promise<StyleAdvice> {
    const raw = await this.gemini().json({
      model: this.opts.model,
      system: STYLE_SYSTEM,
      images: [result],
      text: styleUserText(ctx),
      schema: StyleAdviceSchema,
      label: 'style',
    });
    return finalizeStyleAdvice(raw);
  }
}
