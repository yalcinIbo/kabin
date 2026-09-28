import { ApiError, GoogleGenAI, type Part } from '@google/genai';
import { z } from 'zod';
import { JobError, errorMessage } from '../lib/job_error.js';
import { sniffMime } from '../lib/imaging.js';
import type { ImageBuf } from './types.js';

function toPart(img: ImageBuf): Part {
  return { inlineData: { mimeType: img.mime, data: img.data.toString('base64') } };
}

function mapGeminiError(err: unknown, label: string): JobError {
  if (err instanceof JobError) return err;
  if (err instanceof ApiError) {
    if (err.status === 401 || err.status === 403) {
      return new JobError('provider-not-configured', 'Servis şu anda kullanılamıyor.', `${label} yetki ${err.status}: ${err.message}`);
    }
    if (err.status === 429 || err.status >= 500) {
      return new JobError('provider-failed', 'Servis şu anda yoğun. Lütfen biraz sonra tekrar deneyin.', `${label} ${err.status}: ${err.message}`, true);
    }
    return new JobError('provider-failed', 'Yapay zekâ isteği başarısız oldu.', `${label} ${err.status}: ${err.message}`);
  }
  if (err instanceof Error && (err.name === 'TimeoutError' || err.name === 'AbortError')) {
    return new JobError('provider-timeout', 'İşlem çok uzun sürdü. Lütfen tekrar deneyin.', `${label} zaman aşımı`, true);
  }
  return new JobError('provider-failed', 'Yapay zekâ isteği başarısız oldu.', `${label}: ${errorMessage(err)}`, true);
}

const BLOCK_PATTERN = /SAFETY|PROHIBITED|BLOCKLIST|SPII|RECITATION/;

/** Gemini çağrıları: yapılandırılmış JSON (görsel anlama) ve görsel üretim/düzenleme. */
export class GeminiClient {
  private readonly ai: GoogleGenAI;

  constructor(apiKey: string) {
    this.ai = new GoogleGenAI({ apiKey });
  }

  async json<T extends z.ZodType>(opts: {
    model: string;
    system: string;
    images: ImageBuf[];
    text: string;
    schema: T;
    label: string;
    maxTokens?: number;
  }): Promise<z.infer<T>> {
    const { $schema: _ignored, ...schema } = z.toJSONSchema(opts.schema) as Record<string, unknown>;
    let lastError: JobError | null = null;
    for (let attempt = 0; attempt < 2; attempt++) {
      let response;
      try {
        response = await this.ai.models.generateContent({
          model: opts.model,
          contents: [{ role: 'user', parts: [...opts.images.map(toPart), { text: opts.text }] }],
          config: {
            systemInstruction: opts.system,
            responseMimeType: 'application/json',
            responseJsonSchema: schema,
            maxOutputTokens: opts.maxTokens ?? 4096,
            abortSignal: AbortSignal.timeout(60_000),
          },
        });
      } catch (err) {
        throw mapGeminiError(err, opts.label);
      }
      if (response.promptFeedback?.blockReason) {
        throw new JobError('content-blocked', 'Görsel güvenlik denetiminden geçemedi.', `${opts.label} block: ${response.promptFeedback.blockReason}`);
      }
      const finish = String(response.candidates?.[0]?.finishReason ?? '');
      if (BLOCK_PATTERN.test(finish)) {
        throw new JobError('content-blocked', 'Görsel güvenlik denetiminden geçemedi.', `${opts.label} finish: ${finish}`);
      }
      const text = response.text;
      try {
        if (!text) throw new Error('boş yanıt');
        const parsed = opts.schema.safeParse(JSON.parse(text));
        if (!parsed.success) throw new Error(parsed.error.message.slice(0, 300));
        return parsed.data as z.infer<T>;
      } catch (err) {
        lastError = new JobError('provider-failed', 'Yapay zekâ yanıtı okunamadı. Lütfen tekrar deneyin.', `${opts.label} şema: ${errorMessage(err)}`, true);
      }
    }
    throw lastError ?? new JobError('provider-failed', 'Yapay zekâ yanıtı okunamadı.');
  }

  async image(opts: { model: string; images: ImageBuf[]; text: string; label: string; seed?: number; aspectRatio?: string }): Promise<ImageBuf> {
    let response;
    try {
      response = await this.ai.models.generateContent({
        model: opts.model,
        contents: [{ role: 'user', parts: [...opts.images.map(toPart), { text: opts.text }] }],
        config: {
          responseModalities: ['IMAGE'],
          ...(opts.seed !== undefined ? { seed: opts.seed } : {}),
          ...(opts.aspectRatio ? { imageConfig: { aspectRatio: opts.aspectRatio } } : {}),
          abortSignal: AbortSignal.timeout(120_000),
        },
      });
    } catch (err) {
      throw mapGeminiError(err, opts.label);
    }
    if (response.promptFeedback?.blockReason) {
      throw new JobError('content-blocked', 'Görsel güvenlik denetiminden geçemedi.', `${opts.label} block: ${response.promptFeedback.blockReason}`);
    }
    const candidate = response.candidates?.[0];
    const part = candidate?.content?.parts?.find((p) => p.inlineData?.data && p.inlineData.mimeType?.startsWith('image/'));
    if (!part?.inlineData?.data) {
      const finish = String(candidate?.finishReason ?? 'yok');
      if (BLOCK_PATTERN.test(finish)) {
        throw new JobError('content-blocked', 'Görsel güvenlik denetiminden geçemedi.', `${opts.label} finish: ${finish}`);
      }
      throw new JobError('provider-failed', 'Görsel üretilemedi.', `${opts.label}: görsel yok (finish ${finish})`, true);
    }
    const data = Buffer.from(part.inlineData.data, 'base64');
    return { data, mime: sniffMime(data, part.inlineData.mimeType === 'image/png' ? 'image/png' : 'image/jpeg') };
  }
}
