import { GoogleAuth } from 'google-auth-library';
import { JobError, notConfigured } from '../../lib/job_error.js';
import { flattenOnWhite, sniffMime } from '../../lib/imaging.js';
import type { ImageBuf, SegmentationProvider, TryOnInput, TryOnOutput, TryOnProvider } from '../types.js';

export const VERTEX_COST_PER_IMAGE_USD = 0.06;

export interface VertexOptions {
  projectId: string;
  location: string;
  model: string;
  segmentation: SegmentationProvider;
  /** Testlerde sahte token/fetch verilebilir. */
  getAccessToken?: () => Promise<string>;
  fetchImpl?: typeof fetch;
}

export function vertexEndpoint(o: Pick<VertexOptions, 'projectId' | 'location' | 'model'>): string {
  return `https://${o.location}-aiplatform.googleapis.com/v1/projects/${o.projectId}/locations/${o.location}/publishers/google/models/${o.model}:predict`;
}

export function buildVertexRequest(person: ImageBuf, garment: ImageBuf, sampleCount: number, seed?: number) {
  return {
    instances: [
      {
        personImage: { image: { bytesBase64Encoded: person.data.toString('base64') } },
        productImages: [{ image: { bytesBase64Encoded: garment.data.toString('base64') } }],
      },
    ],
    parameters: {
      sampleCount: Math.max(1, Math.min(4, sampleCount)),
      personGeneration: 'allow_adult',
      outputOptions: { mimeType: 'image/jpeg' },
      ...(seed !== undefined ? { seed } : {}),
    },
  };
}

/** Google Vertex AI Virtual Try-On. Kıyafetin arka planı temiz olmalı; gerekirse önce segmentasyon yapılır. */
export class VertexTryOnProvider implements TryOnProvider {
  readonly id = 'vertex';
  private auth: GoogleAuth | null = null;

  constructor(private readonly opts: VertexOptions) {}

  get available(): boolean {
    return Boolean(this.opts.projectId && this.opts.location && this.opts.model);
  }

  private async token(): Promise<string> {
    if (this.opts.getAccessToken) return this.opts.getAccessToken();
    this.auth ??= new GoogleAuth({ scopes: ['https://www.googleapis.com/auth/cloud-platform'] });
    const token = await this.auth.getAccessToken();
    if (!token) throw notConfigured('Vertex AI kimlik bilgisi');
    return token;
  }

  async run(input: TryOnInput): Promise<TryOnOutput> {
    if (!this.available) throw notConfigured('Vertex AI proje/bölge');
    const started = Date.now();
    let isolated = input.garmentIsolated ?? null;
    let produced: ImageBuf | undefined;
    if (!isolated) {
      isolated = await this.opts.segmentation.removeBackground(input.garment);
      produced = isolated;
    }
    const garment = await flattenOnWhite(isolated);
    const body = buildVertexRequest(input.person, garment, input.numSamples, input.seed);
    const doFetch = this.opts.fetchImpl ?? fetch;
    let res: Response;
    try {
      res = await doFetch(vertexEndpoint(this.opts), {
        method: 'POST',
        headers: { Authorization: `Bearer ${await this.token()}`, 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(180_000),
      });
    } catch (err) {
      if (err instanceof JobError) throw err;
      throw new JobError('provider-failed', 'Servise ulaşılamadı.', `vertex ağ: ${String(err)}`, true);
    }
    const text = await res.text();
    if (!res.ok) {
      const detail = `vertex ${res.status}: ${text.slice(0, 400)}`;
      if (res.status === 401 || res.status === 403) throw new JobError('provider-not-configured', 'Servis şu anda kullanılamıyor.', detail);
      if (res.status === 429 || res.status >= 500) {
        throw new JobError('provider-failed', 'Servis şu anda yoğun. Lütfen biraz sonra tekrar deneyin.', detail, true);
      }
      if (/safety|responsible ai|filtered/i.test(text)) throw new JobError('content-blocked', 'Görsel güvenlik denetiminden geçemedi.', detail);
      throw new JobError('invalid-input', 'Görsel bu işlem için uygun bulunmadı.', detail);
    }
    const json = JSON.parse(text) as { predictions?: Array<{ bytesBase64Encoded?: string; raiFilteredReason?: string }> };
    const predictions = json.predictions ?? [];
    const images = predictions
      .map((p) => p.bytesBase64Encoded)
      .filter((b): b is string => Boolean(b))
      .map((b) => {
        const data = Buffer.from(b, 'base64');
        return { provider: this.id, image: { data, mime: sniffMime(data) } };
      });
    if (images.length === 0) {
      const reason = predictions.find((p) => p.raiFilteredReason)?.raiFilteredReason;
      if (reason) throw new JobError('content-blocked', 'Görsel güvenlik denetiminden geçemedi.', `vertex rai: ${reason}`);
      throw new JobError('provider-failed', 'Görsel üretilemedi.', 'vertex: boş sonuç');
    }
    return {
      images,
      costUsd: VERTEX_COST_PER_IMAGE_USD * images.length,
      durationMs: Date.now() - started,
      ...(produced ? { garmentIsolated: produced } : {}),
    };
  }
}
