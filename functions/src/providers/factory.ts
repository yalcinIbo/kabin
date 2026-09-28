import { FakeImageProvider, FakeModel3DProvider, FakeSegmentation, FakeTryOnProvider, FakeVisionAnalyzer } from './fake.js';
import { GeminiImageProvider } from './imagegen/gemini.js';
import { FalHunyuan3DProvider } from './model3d/fal_hunyuan.js';
import { FalTripo3DProvider } from './model3d/fal_tripo.js';
import { HfTrellis3DProvider } from './model3d/hf_trellis.js';
import { HfTrellis2Provider } from './model3d/hf_trellis2.js';
import { FalBirefnetSegmentation } from './segmentation/fal_birefnet.js';
import { GeminiSegmentation } from './segmentation/gemini.js';
import { CompositeTryOnProvider } from './tryon/composite.js';
import { GeminiVisionAnalyzer } from './vision/gemini.js';
import { FashnTryOnProvider } from './tryon/fashn.js';
import { GeminiTryOnProvider } from './tryon/gemini.js';
import { VertexTryOnProvider } from './tryon/vertex.js';
import type { Model3DChoice, Model3DProvider, ProviderSet, SegmentationChoice, SegmentationProvider, TryOnChoice, TryOnProvider } from './types.js';

export const MOCK_KINDS = ['tryon', 'segmentation', 'imagegen', 'model3d', 'vision'] as const;
export type MockKind = (typeof MOCK_KINDS)[number];

export interface ProviderConfig {
  falKey: string;
  geminiKey: string;
  /** İsteğe bağlı Hugging Face anahtarı (TRELLIS ücretsiz GPU kotasını artırır). */
  hfToken: string;
  tryon: TryOnChoice;
  model3d: Model3DChoice;
  segmentation: SegmentationChoice;
  vertex: { projectId: string; location: string; model: string };
  gemini: { visionModel: string; imageModel: string };
  mock: ReadonlySet<MockKind>;
}

export function parseMockList(value: string): Set<MockKind> {
  const v = value.trim().toLowerCase();
  if (v === 'all' || v === 'true' || v === '1') return new Set(MOCK_KINDS);
  if (!v || v === 'none' || v === 'false' || v === '0') return new Set();
  return new Set(v.split(',').map((s) => s.trim()).filter((s): s is MockKind => (MOCK_KINDS as readonly string[]).includes(s)));
}

/** Saf fabrika: Firebase'e bağımlı değildir; benchmark script'i de bunu kullanır. */
export function createProviders(cfg: ProviderConfig): ProviderSet {
  const mock = (k: MockKind) => cfg.mock.has(k);
  const segmentation: SegmentationProvider = mock('segmentation')
    ? new FakeSegmentation()
    : cfg.segmentation === 'birefnet'
      ? new FalBirefnetSegmentation({ falKey: cfg.falKey })
      : new GeminiSegmentation({ apiKey: cfg.geminiKey, model: cfg.gemini.imageModel });
  const imagegen = mock('imagegen') ? new FakeImageProvider() : new GeminiImageProvider({ apiKey: cfg.geminiKey, model: cfg.gemini.imageModel });
  const vision = mock('vision') ? new FakeVisionAnalyzer() : new GeminiVisionAnalyzer({ apiKey: cfg.geminiKey, model: cfg.gemini.visionModel });

  const single = (id: 'fashn' | 'vertex' | 'gemini'): TryOnProvider => {
    if (mock('tryon')) return new FakeTryOnProvider(`fake-${id}`);
    if (id === 'gemini') return new GeminiTryOnProvider({ apiKey: cfg.geminiKey, model: cfg.gemini.imageModel });
    return id === 'fashn'
      ? new FashnTryOnProvider({ falKey: cfg.falKey })
      : new VertexTryOnProvider({ ...cfg.vertex, segmentation });
  };

  return {
    tryOn: (choice) => (choice === 'both' ? new CompositeTryOnProvider([single('fashn'), single('vertex')]) : single(choice)),
    segmentation: () => segmentation,
    multiView: () => imagegen,
    avatar: () => imagegen,
    model3d: (choice): Model3DProvider => {
      if (mock('model3d')) return new FakeModel3DProvider();
      if (choice === 'tripo') return new FalTripo3DProvider({ falKey: cfg.falKey });
      if (choice === 'hunyuan') return new FalHunyuan3DProvider({ falKey: cfg.falKey });
      if (choice === 'trellis') return new HfTrellis3DProvider({ hfToken: cfg.hfToken });
      return new HfTrellis2Provider({ hfToken: cfg.hfToken });
    },
    vision: () => vision,
  };
}

export function createFakeProviders(delays: { tryon?: number; image?: number; model3d?: number } = {}): ProviderSet {
  const segmentation = new FakeSegmentation();
  const imagegen = new FakeImageProvider(delays.image ?? 0);
  const vision = new FakeVisionAnalyzer();
  return {
    tryOn: (choice) =>
      choice === 'both'
        ? new CompositeTryOnProvider([new FakeTryOnProvider('fake-fashn', delays.tryon ?? 0), new FakeTryOnProvider('fake-vertex', delays.tryon ?? 0)])
        : new FakeTryOnProvider(`fake-${choice}`, delays.tryon ?? 0),
    segmentation: () => segmentation,
    multiView: () => imagegen,
    avatar: () => imagegen,
    model3d: () => new FakeModel3DProvider('fake-3d', delays.model3d ?? 0),
    vision: () => vision,
  };
}
