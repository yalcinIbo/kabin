import { defineSecret, defineString } from 'firebase-functions/params';
import { parseMockList, type ProviderConfig } from '../providers/factory.js';

export const FAL_KEY = defineSecret('FAL_KEY');
export const GEMINI_API_KEY = defineSecret('GEMINI_API_KEY');
export const HF_TOKEN = defineSecret('HF_TOKEN');
export const AI_SECRETS = [FAL_KEY, GEMINI_API_KEY, HF_TOKEN];

// Varsayılanlar ücretsiz/ücretsize yakın yol: Gemini try-on + Gemini kıyafet izolasyonu + TRELLIS.2 3D.
export const TRYON_PROVIDER = defineString('TRYON_PROVIDER', { default: 'gemini' });
export const MODEL3D_PROVIDER = defineString('MODEL3D_PROVIDER', { default: 'trellis2' });
export const SEGMENTATION_PROVIDER = defineString('SEGMENTATION_PROVIDER', { default: 'gemini' });
export const VERTEX_LOCATION = defineString('VERTEX_LOCATION', { default: 'us-central1' });
export const VERTEX_TRYON_MODEL = defineString('VERTEX_TRYON_MODEL', { default: 'virtual-try-on-001' });
export const GEMINI_VISION_MODEL = defineString('GEMINI_VISION_MODEL', { default: 'gemini-3.8-flash' });
export const GEMINI_IMAGE_MODEL = defineString('GEMINI_IMAGE_MODEL', { default: 'gemini-3.1-flash-image' });
export const MOCK_PROVIDERS = defineString('MOCK_PROVIDERS', { default: 'none' });

function read(param: { value(): string }, fallback: string): string {
  try {
    const v = param.value();
    return v && v.trim() ? v.trim() : fallback;
  } catch {
    return fallback;
  }
}

/** `.secret.local` içindeki `unset` yer tutucusu boş anahtar sayılır (emülatör Secret Manager'a gitmesin diye). */
function secret(param: { value(): string }): string {
  const v = read(param, '');
  return v === 'unset' ? '' : v;
}

/** Fonksiyon çalışırken parametre ve gizli anahtarlardan sağlayıcı yapılandırması üretir. */
export function runtimeProviderConfig(): ProviderConfig {
  const tryon = read(TRYON_PROVIDER, 'gemini');
  const model3d = read(MODEL3D_PROVIDER, 'trellis2');
  const segmentation = read(SEGMENTATION_PROVIDER, 'gemini');
  return {
    falKey: secret(FAL_KEY),
    geminiKey: secret(GEMINI_API_KEY),
    hfToken: secret(HF_TOKEN),
    tryon: tryon === 'fashn' || tryon === 'vertex' || tryon === 'both' ? tryon : 'gemini',
    model3d: model3d === 'trellis' || model3d === 'tripo' || model3d === 'hunyuan' ? model3d : 'trellis2',
    segmentation: segmentation === 'birefnet' ? 'birefnet' : 'gemini',
    vertex: {
      projectId: process.env.GCLOUD_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT ?? '',
      location: read(VERTEX_LOCATION, 'us-central1'),
      model: read(VERTEX_TRYON_MODEL, 'virtual-try-on-001'),
    },
    gemini: {
      visionModel: read(GEMINI_VISION_MODEL, 'gemini-3.8-flash'),
      imageModel: read(GEMINI_IMAGE_MODEL, 'gemini-3.1-flash-image'),
    },
    mock: parseMockList(read(MOCK_PROVIDERS, 'none')),
  };
}
