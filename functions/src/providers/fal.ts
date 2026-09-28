import { ApiError, ValidationError, createFalClient } from '@fal-ai/client';
import { JobError, errorMessage } from '../lib/job_error.js';
import { sniffMime } from '../lib/imaging.js';
import type { ImageBuf } from './types.js';

/** Testlerde sahtesi verilebilen en küçük fal istemci yüzeyi. */
export interface FalLike {
  subscribe(endpoint: string, options: { input: Record<string, unknown>; abortSignal?: AbortSignal }): Promise<{ data: unknown; requestId: string }>;
  storage: { upload(file: Blob): Promise<string> };
}

export function createFal(key: string): FalLike {
  const client = createFalClient({ credentials: key });
  return {
    subscribe: (endpoint, options) =>
      client.subscribe(endpoint, options as Parameters<typeof client.subscribe>[1]) as Promise<{ data: unknown; requestId: string }>,
    storage: { upload: (file) => client.storage.upload(file) },
  };
}

export async function falUpload(fal: FalLike, img: ImageBuf): Promise<string> {
  try {
    return await fal.storage.upload(new Blob([Uint8Array.from(img.data)], { type: img.mime }));
  } catch (err) {
    throw mapFalError(err, 'fal-upload');
  }
}

export async function falRun<T>(
  fal: FalLike,
  endpoint: string,
  input: Record<string, unknown>,
  label: string,
  timeoutMs: number,
): Promise<T> {
  try {
    const { data } = await fal.subscribe(endpoint, { input, abortSignal: AbortSignal.timeout(timeoutMs) });
    return data as T;
  } catch (err) {
    throw mapFalError(err, label);
  }
}

export function mapFalError(err: unknown, label: string): JobError {
  if (err instanceof JobError) return err;
  if (err instanceof Error && (err.name === 'TimeoutError' || err.name === 'AbortError')) {
    return new JobError('provider-timeout', 'İşlem çok uzun sürdü. Lütfen tekrar deneyin.', `${label} zaman aşımı`, true);
  }
  if (err instanceof ValidationError) {
    const text = JSON.stringify(err.body ?? {}).slice(0, 400);
    if (/moderat|nsfw|safety|inappropriate/i.test(text)) {
      return new JobError('content-blocked', 'Görsel güvenlik denetiminden geçemedi.', `${label}: ${text}`);
    }
    return new JobError('invalid-input', 'Görsel bu işlem için uygun bulunmadı. Farklı bir fotoğraf deneyin.', `${label} 422: ${text}`);
  }
  if (err instanceof ApiError) {
    if (err.status === 401 || err.status === 403) {
      const body = JSON.stringify(err.body ?? {}).slice(0, 300);
      return new JobError('provider-not-configured', 'Servis şu anda kullanılamıyor.', `${label} yetki hatası ${err.status}: ${body}`);
    }
    if (err.status === 429 || err.status >= 500) {
      return new JobError('provider-failed', 'Servis şu anda yoğun. Lütfen biraz sonra tekrar deneyin.', `${label} ${err.status}: ${err.message}`, true);
    }
    return new JobError('provider-failed', 'Görsel üretilemedi.', `${label} ${err.status}: ${err.message}`);
  }
  return new JobError('provider-failed', 'Görsel üretilemedi.', `${label}: ${errorMessage(err)}`, true);
}

export async function fetchBinary(url: string, timeoutMs = 120_000): Promise<{ data: Buffer; contentType: string }> {
  const res = await fetch(url, { signal: AbortSignal.timeout(timeoutMs) });
  if (!res.ok) throw new JobError('provider-failed', 'Sonuç dosyası indirilemedi.', `GET ${url} → ${res.status}`, true);
  return { data: Buffer.from(await res.arrayBuffer()), contentType: res.headers.get('content-type') ?? '' };
}

export async function fetchImage(url: string): Promise<ImageBuf> {
  const { data, contentType } = await fetchBinary(url);
  const fromHeader = contentType.includes('png') ? 'image/png' : contentType.includes('webp') ? 'image/webp' : 'image/jpeg';
  return { data, mime: sniffMime(data, fromHeader) };
}

export interface FalFile {
  url: string;
  content_type?: string;
  file_size?: number;
}
