import { errorMessage } from '../lib/job_error.js';
import type { ImageBuf, ProviderPhotoType, TryOnCategory, TryOnProvider } from '../providers/types.js';

export interface BenchmarkPairInput {
  person: ImageBuf;
  garment: ImageBuf;
  garmentIsolated?: ImageBuf | null;
  category: TryOnCategory;
  garmentPhotoType: ProviderPhotoType;
  seed?: number;
}

export interface ProviderRun {
  provider: string;
  ok: boolean;
  image?: ImageBuf;
  ms: number;
  costUsd: number;
  error?: string;
  garmentIsolated?: ImageBuf;
}

/** Aynı (kişi, kıyafet) çiftini her sağlayıcıda ayrı ayrı çalıştırır; süre ve maliyeti ölçer. */
export async function runPair(providers: TryOnProvider[], pair: BenchmarkPairInput): Promise<ProviderRun[]> {
  return Promise.all(
    providers.map(async (p): Promise<ProviderRun> => {
      const started = Date.now();
      try {
        const out = await p.run({
          person: pair.person,
          garment: pair.garment,
          garmentIsolated: pair.garmentIsolated ?? null,
          category: pair.category,
          garmentPhotoType: pair.garmentPhotoType,
          numSamples: 1,
          ...(pair.seed !== undefined ? { seed: pair.seed } : {}),
          mode: 'balanced',
        });
        return {
          provider: p.id,
          ok: true,
          image: out.images[0]?.image,
          ms: Date.now() - started,
          costUsd: out.costUsd,
          ...(out.garmentIsolated ? { garmentIsolated: out.garmentIsolated } : {}),
        };
      } catch (err) {
        return { provider: p.id, ok: false, ms: Date.now() - started, costUsd: 0, error: errorMessage(err).slice(0, 400) };
      }
    }),
  );
}
