import { handle_file } from '@gradio/client';
import sharp from 'sharp';
import { JobError, notConfigured } from '../../lib/job_error.js';
import { normalizeJpeg } from '../../lib/imaging.js';
import type { ImageBuf, Model3DProvider, Model3DResult } from '../types.js';
import {
  type FileFetcher,
  type GradioConnect,
  type GradioLike,
  defaultConnect,
  defaultFetch,
  fileUrl,
  mapTrellisError,
  withTimeout,
} from './hf_trellis.js';

/** Microsoft TRELLIS.2 (MIT, Aralık 2025) — Hugging Face'teki resmi demo. PBR dokulu, TRELLIS'ten belirgin şekilde daha net. */
export const TRELLIS2_SPACE = 'microsoft/TRELLIS.2';
/** Üretim (~30 sn) + GLB çıkarma (~45 sn) + kuyruk payı; fonksiyon süresi 540 sn. */
export const TRELLIS2_TIMEOUT_MS = 480_000;

export interface Trellis2Settings {
  /** '1024' iyi denge; '1536' daha net ama daha yavaş ve kotayı hızlı bitirir. */
  resolution: '512' | '1024' | '1536';
  /** GLB'deki hedef üçgen sayısı. Demo varsayılanı 300 bin. */
  decimationTarget: number;
  /** Doku çözünürlüğü (1024-4096). */
  textureSize: number;
}

export const TRELLIS2_DEFAULTS: Trellis2Settings = { resolution: '1024', decimationTarget: 300_000, textureSize: 2048 };

/** Demo, ışıklandırılmış önizlemeleri HTML içinde base64 <img> olarak döner; s4 önden görünüm. */
export function extractTrellis2Preview(html: string): Buffer | null {
  const pick = (mode: string, step: string) => {
    const re = new RegExp(`id="view-m${mode}-s${step}"[^>]*?src="data:image/(?:jpeg|png);base64,([^"]+)"`);
    return re.exec(html)?.[1] ?? null;
  };
  const b64 = pick('3', '4') ?? pick('\\d+', '4') ?? pick('\\d+', '\\d+');
  return b64 ? Buffer.from(b64, 'base64') : null;
}

/** Siyah render fonunu kırpıp kenar boşluğu bırakır. */
async function tidyPreview(buf: Buffer): Promise<ImageBuf> {
  const trimmed = await sharp(buf).trim({ background: '#000000', threshold: 12 }).toBuffer();
  const padded = await sharp(trimmed)
    .extend({ top: 24, bottom: 24, left: 24, right: 24, background: '#000000' })
    .jpeg({ quality: 90 })
    .toBuffer();
  return normalizeJpeg(padded);
}

/**
 * TRELLIS.2 ile görselden dokulu GLB. Demo arka planı kendisi siler (BRIA RMBG), ayrı segmentasyon gerekmez.
 * Ara durum Gradio oturumunda (gr.State) tutulur; bu yüzden tüm adımlar aynı istemci bağlantısıyla sırayla çağrılır.
 */
export class HfTrellis2Provider implements Model3DProvider {
  readonly id = 'trellis2';
  readonly needsIsolatedInput = false;

  constructor(
    private readonly opts: {
      hfToken?: string;
      space?: string;
      settings?: Partial<Trellis2Settings>;
      connect?: GradioConnect;
      fetchFile?: FileFetcher;
      timeoutMs?: number;
      enabled?: boolean;
    } = {},
  ) {}

  get available(): boolean {
    return this.opts.enabled ?? true;
  }

  async generate(img: ImageBuf): Promise<Model3DResult> {
    if (!this.available) throw notConfigured('TRELLIS.2');
    const started = Date.now();
    const token = this.opts.hfToken || undefined;
    const settings = { ...TRELLIS2_DEFAULTS, ...this.opts.settings };
    const connect = this.opts.connect ?? defaultConnect;
    const fetchFile = this.opts.fetchFile ?? defaultFetch;
    let app: GradioLike | null = null;
    try {
      return await withTimeout(
        (async () => {
          app = await connect(this.opts.space ?? TRELLIS2_SPACE, token).catch((e: unknown) => {
            throw mapTrellisError(e, 'bağlantı', 'trellis2');
          });
          const client = app;
          const step = async (endpoint: string, data: Record<string, unknown>) => {
            try {
              return await client.predict(endpoint, data);
            } catch (e) {
              throw mapTrellisError(e, endpoint, 'trellis2');
            }
          };

          await step('/start_session', {});
          const blob = new Blob([new Uint8Array(img.data)], { type: img.mime });
          const pre = await step('/preprocess_image', { input: handle_file(blob) });
          const prepared = (pre.data as unknown[])[0];
          if (!fileUrl(prepared)) throw new JobError('provider-failed', '3D model üretilemedi.', 'trellis2: ön işleme görseli yok', true);

          const gen = await step('/image_to_3d', {
            image: prepared,
            seed: 0,
            resolution: settings.resolution,
            ss_guidance_strength: 7.5,
            ss_guidance_rescale: 0.7,
            ss_sampling_steps: 12,
            ss_rescale_t: 5,
            shape_slat_guidance_strength: 7.5,
            shape_slat_guidance_rescale: 0.5,
            shape_slat_sampling_steps: 12,
            shape_slat_rescale_t: 3,
            tex_slat_guidance_strength: 1,
            tex_slat_guidance_rescale: 0,
            tex_slat_sampling_steps: 12,
            tex_slat_rescale_t: 3,
          });
          const html = String((gen.data as unknown[])[0] ?? '');

          const out = await step('/extract_glb', { decimation_target: settings.decimationTarget, texture_size: settings.textureSize });
          const data = out.data as unknown[];
          const glbUrl = fileUrl(data[1]) ?? fileUrl(data[0]);
          if (!glbUrl) throw new JobError('provider-failed', '3D model üretilemedi.', 'trellis2: GLB çıktısı yok', true);
          const glb = await fetchFile(glbUrl, token).catch((e: unknown) => {
            throw mapTrellisError(e, 'glb indirme', 'trellis2');
          });

          const rawPreview = extractTrellis2Preview(html);
          const preview = rawPreview ? await tidyPreview(rawPreview).catch(() => undefined) : undefined;
          return { glb, ...(preview ? { preview } : {}), costUsd: 0, durationMs: Date.now() - started };
        })(),
        this.opts.timeoutMs ?? TRELLIS2_TIMEOUT_MS,
      );
    } finally {
      try {
        (app as GradioLike | null)?.close?.();
      } catch {
        /* bağlantı zaten kapalı */
      }
    }
  }
}
