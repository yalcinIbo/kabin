import { JobError, errorMessage } from '../../lib/job_error.js';
import type { TryOnInput, TryOnOutput, TryOnProvider } from '../types.js';

/** Birden çok sağlayıcıyı paralel çalıştırır (karşılaştırma modu). En az biri başarılıysa sonuç döner. */
export class CompositeTryOnProvider implements TryOnProvider {
  readonly id = 'both';

  constructor(private readonly members: TryOnProvider[]) {}

  get available(): boolean {
    return this.members.some((m) => m.available);
  }

  async run(input: TryOnInput): Promise<TryOnOutput> {
    const started = Date.now();
    const settled = await Promise.allSettled(this.members.map((m) => m.run(input)));
    const out: TryOnOutput = { images: [], costUsd: 0, durationMs: 0, failures: [] };
    let firstError: unknown = null;
    settled.forEach((r, i) => {
      const provider = this.members[i]!.id;
      if (r.status === 'fulfilled') {
        out.images.push(...r.value.images);
        out.costUsd += r.value.costUsd;
        if (r.value.garmentIsolated) out.garmentIsolated = r.value.garmentIsolated;
      } else {
        firstError ??= r.reason;
        out.failures!.push({ provider, message: errorMessage(r.reason).slice(0, 300) });
      }
    });
    out.durationMs = Date.now() - started;
    if (out.images.length === 0) {
      if (firstError instanceof JobError) throw firstError;
      throw new JobError('provider-failed', 'Görsel üretilemedi.', errorMessage(firstError));
    }
    return out;
  }
}
