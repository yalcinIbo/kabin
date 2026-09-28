import { db } from '../lib/admin.js';
import { FP } from '../lib/paths.js';

export interface DailyCaps {
  tryon: number;
  model3d: number;
  avatar: number;
  analysis: number;
}

export interface Pricing {
  tryon: number;
  multiView: number;
  model3d: number;
  avatar: number;
  welcome: number;
  dailyCaps: DailyCaps;
}

export interface Flags {
  tryonEnabled: boolean;
  model3dEnabled: boolean;
  avatarEnabled: boolean;
}

export const DEFAULT_PRICING: Pricing = {
  tryon: 1,
  multiView: 1,
  model3d: 5,
  avatar: 1,
  welcome: 10,
  dailyCaps: { tryon: 30, model3d: 5, avatar: 5, analysis: 80 },
};

// 3D model şimdilik kapalı: ücretsiz kota yetersiz, kalite 2D çoklu açının gerisinde. Kod duruyor; config/flags ile açılabilir.
export const DEFAULT_FLAGS: Flags = { tryonEnabled: true, model3dEnabled: false, avatarEnabled: true };

const TTL_MS = 60_000;
let pricingCache: { value: Pricing; at: number } | null = null;
let flagsCache: { value: Flags; at: number } | null = null;

function num(v: unknown, fallback: number): number {
  return typeof v === 'number' && Number.isFinite(v) && v >= 0 ? Math.floor(v) : fallback;
}

export function mergePricing(raw: Record<string, unknown> | undefined): Pricing {
  const caps = (raw?.dailyCaps ?? {}) as Record<string, unknown>;
  return {
    tryon: num(raw?.tryon, DEFAULT_PRICING.tryon),
    multiView: num(raw?.multiView, DEFAULT_PRICING.multiView),
    model3d: num(raw?.model3d, DEFAULT_PRICING.model3d),
    avatar: num(raw?.avatar, DEFAULT_PRICING.avatar),
    welcome: num(raw?.welcome, DEFAULT_PRICING.welcome),
    dailyCaps: {
      tryon: num(caps.tryon, DEFAULT_PRICING.dailyCaps.tryon),
      model3d: num(caps.model3d, DEFAULT_PRICING.dailyCaps.model3d),
      avatar: num(caps.avatar, DEFAULT_PRICING.dailyCaps.avatar),
      analysis: num(caps.analysis, DEFAULT_PRICING.dailyCaps.analysis),
    },
  };
}

export async function loadPricing(): Promise<Pricing> {
  if (pricingCache && Date.now() - pricingCache.at < TTL_MS) return pricingCache.value;
  const snap = await db.doc(FP.pricing).get();
  const value = mergePricing(snap.data());
  pricingCache = { value, at: Date.now() };
  return value;
}

export async function loadFlags(): Promise<Flags> {
  if (flagsCache && Date.now() - flagsCache.at < TTL_MS) return flagsCache.value;
  const raw = (await db.doc(FP.flags).get()).data() ?? {};
  const bool = (v: unknown, d: boolean) => (typeof v === 'boolean' ? v : d);
  const value: Flags = {
    tryonEnabled: bool(raw.tryonEnabled, DEFAULT_FLAGS.tryonEnabled),
    model3dEnabled: bool(raw.model3dEnabled, DEFAULT_FLAGS.model3dEnabled),
    avatarEnabled: bool(raw.avatarEnabled, DEFAULT_FLAGS.avatarEnabled),
  };
  flagsCache = { value, at: Date.now() };
  return value;
}

/** Testler için önbelleği temizler. */
export function resetConfigCache(): void {
  pricingCache = null;
  flagsCache = null;
}
