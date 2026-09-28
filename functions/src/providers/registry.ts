import { runtimeProviderConfig } from '../config/params.js';
import { createProviders, type ProviderConfig } from './factory.js';
import type { ProviderSet } from './types.js';

let current: ProviderSet | null = null;
let currentConfig: ProviderConfig | null = null;

/** Çalışma zamanı sağlayıcıları (fonksiyon örneği başına bir kez kurulur). */
export function providers(): ProviderSet {
  if (current) return current;
  currentConfig = runtimeProviderConfig();
  current = createProviders(currentConfig);
  return current;
}

/** İstekte saklanacak varsayılan sağlayıcı kimlikleri. */
export function providerDefaults(): Pick<ProviderConfig, 'tryon' | 'model3d'> & { mock: string[] } {
  const cfg = currentConfig ?? runtimeProviderConfig();
  return { tryon: cfg.tryon, model3d: cfg.model3d, mock: [...cfg.mock] };
}

/** Testler için sağlayıcıları değiştirir; `null` ile sıfırlanır. */
export function setProviders(set: ProviderSet | null, defaults?: ProviderConfig): void {
  current = set;
  currentConfig = defaults ?? null;
}
