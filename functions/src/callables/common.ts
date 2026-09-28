import { z } from 'zod';
import { httpsError, jobErrorToHttps } from '../lib/https.js';
import { toJobError } from '../lib/job_error.js';

export interface Caller {
  uid: string;
  isAdmin: boolean;
  /** Son kimlik doğrulama zamanı (saniye). */
  authTime?: number;
}

export function parseInput<T extends z.ZodType>(schema: T, raw: unknown): z.infer<T> {
  const parsed = schema.safeParse(raw ?? {});
  if (!parsed.success) {
    throw httpsError('invalid-argument', 'İstek geçersiz.', 'invalid-argument', {
      issues: parsed.error.issues.slice(0, 5).map((i) => `${i.path.join('.')}: ${i.message}`),
    });
  }
  return parsed.data;
}

/** Sağlayıcı/iş hatasını Türkçe callable hatasına çevirerek yeniden fırlatır. */
export async function guardJob<T>(fn: () => Promise<T>): Promise<T> {
  try {
    return await fn();
  } catch (err) {
    if (err instanceof Error && err.name === 'HttpsError') throw err;
    throw jobErrorToHttps(toJobError(err));
  }
}

export const idSchema = z.string().min(1).max(128).regex(/^[A-Za-z0-9_-]+$/);
