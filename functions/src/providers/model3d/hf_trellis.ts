import { Client, handle_file } from '@gradio/client';
import { JobError, errorMessage, notConfigured } from '../../lib/job_error.js';
import { normalizePng } from '../../lib/imaging.js';
import type { ImageBuf, Model3DProvider, Model3DResult } from '../types.js';

/** Microsoft TRELLIS (MIT) — Hugging Face'teki herkese açık demo. Ücretsiz, ZeroGPU kotasıyla sınırlı. */
export const TRELLIS_SPACE = 'trellis-community/TRELLIS';
export const TRELLIS_TIMEOUT_MS = 420_000;

interface GradioFile {
  url?: string;
  path?: string;
}

/** Testlerde sahte istemci verilebilsin diye @gradio/client'ın kullandığımız kısmı. */
export interface GradioLike {
  predict(endpoint: string, data: Record<string, unknown>): Promise<{ data: unknown }>;
  close?(): void;
}

export type GradioConnect = (space: string, token?: string) => Promise<GradioLike>;
export type FileFetcher = (url: string, token?: string) => Promise<Buffer>;

export const defaultConnect: GradioConnect = async (space, token) =>
  (await Client.connect(space, token ? { token: token as `hf_${string}` } : {})) as unknown as GradioLike;

export const defaultFetch: FileFetcher = async (url, token) => {
  const res = await fetch(url, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
    signal: AbortSignal.timeout(120_000),
  });
  if (!res.ok) throw new Error(`dosya indirilemedi: HTTP ${res.status}`);
  return Buffer.from(await res.arrayBuffer());
};

/** Gradio hata nesnesinden (Error + title/message alanları) okunabilir metin çıkarır. */
function gradioErrorText(err: unknown): string {
  if (err && typeof err === 'object') {
    const e = err as { title?: unknown; message?: unknown; original_msg?: unknown };
    const parts = [e.title, e.message, e.original_msg].filter((p): p is string => typeof p === 'string' && p.length > 0);
    if (parts.length) return [...new Set(parts)].join(' | ');
  }
  return errorMessage(err);
}

export function mapTrellisError(err: unknown, step: string, label = 'trellis'): JobError {
  if (err instanceof JobError) return err;
  const text = gradioErrorText(err);
  const detail = `${label} ${step}: ${text}`.slice(0, 500);
  if (/quota/i.test(text)) {
    return new JobError('provider-failed', 'Ücretsiz 3D kotası doldu. Lütfen daha sonra tekrar deneyin.', detail);
  }
  if (/no gpu|queue is full|too many|429/i.test(text)) {
    return new JobError('provider-failed', '3D servisi şu anda yoğun. Lütfen biraz sonra tekrar deneyin.', detail, true);
  }
  if (/sleeping|paused|building|runtime_error|could not resolve|fetch failed|ENOTFOUND|ECONNRESET/i.test(text)) {
    return new JobError('provider-failed', '3D servisine şu anda ulaşılamıyor.', detail, true);
  }
  return new JobError('provider-failed', '3D model üretilemedi.', detail, true);
}

export function fileUrl(value: unknown): string | null {
  const f = value as GradioFile | null | undefined;
  return f && typeof f === 'object' && typeof f.url === 'string' ? f.url : null;
}

export function withTimeout<T>(p: Promise<T>, ms: number): Promise<T> {
  let timer: NodeJS.Timeout | undefined;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(
      () => reject(new JobError('provider-timeout', '3D model üretimi çok uzun sürdü. Lütfen tekrar deneyin.', 'trellis zaman aşımı', true)),
      ms,
    );
  });
  return Promise.race([p, timeout]).finally(() => clearTimeout(timer));
}

/**
 * Görselden dokulu GLB. Demo arka planı kendisi sildiği için ayrı segmentasyon adımı gerekmez.
 * `hfToken` isteğe bağlıdır; ücretsiz bir Hugging Face hesabının anahtarı günlük GPU kotasını artırır.
 */
export class HfTrellis3DProvider implements Model3DProvider {
  readonly id = 'trellis';
  readonly needsIsolatedInput = false;

  constructor(
    private readonly opts: {
      hfToken?: string;
      space?: string;
      connect?: GradioConnect;
      fetchFile?: FileFetcher;
      timeoutMs?: number;
      enabled?: boolean;
    } = {},
  ) {}

  /** Herkese açık demo anahtarsız da çağrılabilir; `enabled:false` ile kapatılabilir. */
  get available(): boolean {
    return this.opts.enabled ?? true;
  }

  async generate(img: ImageBuf): Promise<Model3DResult> {
    if (!this.available) throw notConfigured('TRELLIS');
    const started = Date.now();
    const token = this.opts.hfToken || undefined;
    const connect = this.opts.connect ?? defaultConnect;
    const fetchFile = this.opts.fetchFile ?? defaultFetch;
    let app: GradioLike | null = null;
    try {
      return await withTimeout(
        (async () => {
          app = await connect(this.opts.space ?? TRELLIS_SPACE, token).catch((e: unknown) => {
            throw mapTrellisError(e, 'bağlantı');
          });
          const client = app;
          const step = async (endpoint: string, data: Record<string, unknown>) => {
            try {
              return await client.predict(endpoint, data);
            } catch (e) {
              throw mapTrellisError(e, endpoint);
            }
          };
          // Demo, oturum klasörünü bu çağrıda açar; atlanırsa üretim FileNotFoundError verir.
          await step('/start_session', {});
          const blob = new Blob([new Uint8Array(img.data)], { type: img.mime });
          const pre = await step('/preprocess_image', { image: handle_file(blob) });
          const prepared = (pre.data as unknown[])[0];
          if (!fileUrl(prepared)) throw new JobError('provider-failed', '3D model üretilemedi.', 'trellis: ön işleme görseli yok', true);

          const out = await step('/generate_and_extract_glb', {
            image: prepared,
            multiimages: [],
            seed: 0,
            ss_guidance_strength: 7.5,
            ss_sampling_steps: 12,
            slat_guidance_strength: 3,
            slat_sampling_steps: 12,
            multiimage_algo: 'stochastic',
            mesh_simplify: 0.95,
            texture_size: 1024,
          });
          const data = out.data as unknown[];
          const glbUrl = fileUrl(data[2]) ?? fileUrl(data[1]);
          if (!glbUrl) throw new JobError('provider-failed', '3D model üretilemedi.', 'trellis: GLB çıktısı yok', true);

          const glb = await fetchFile(glbUrl, token).catch((e: unknown) => {
            throw mapTrellisError(e, 'glb indirme');
          });
          // Arka planı silinmiş ön işleme görseli önizleme olarak kullanılır; alınamazsa pipeline kaynak görseli kullanır.
          const preview = await fetchFile(fileUrl(prepared)!, token)
            .then((buf) => normalizePng(buf))
            .catch(() => undefined);
          return { glb, ...(preview ? { preview } : {}), costUsd: 0, durationMs: Date.now() - started };
        })(),
        this.opts.timeoutMs ?? TRELLIS_TIMEOUT_MS,
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
