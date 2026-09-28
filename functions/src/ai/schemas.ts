import { z } from 'zod';
import type { ProviderPhotoType, TryOnCategory } from '../providers/types.js';

// Şemalar Gemini'ye `responseJsonSchema` olarak gönderilir; bu yüzden regex/uzunluk
// kısıtları şemaya konmaz, yanıt geldikten sonra `finalize*` fonksiyonlarında normalize edilir.

export const PHOTO_ISSUES = [
  'no_person',
  'multiple_people',
  'cropped_body',
  'arms_covering',
  'side_pose',
  'dark',
  'blurry',
  'low_resolution',
  'minor',
  'nudity',
] as const;
export type PhotoIssue = (typeof PHOTO_ISSUES)[number];

export const PhotoQcSchema = z.object({
  singlePerson: z.boolean(),
  fullBodyVisible: z.boolean(),
  armsClearOfTorso: z.boolean(),
  frontFacing: z.boolean(),
  lightingOk: z.boolean(),
  sharp: z.boolean(),
  appearsAdult: z.boolean(),
  nudity: z.boolean(),
  issues: z.array(z.enum(PHOTO_ISSUES)),
  hintTr: z.string(),
});
export type PhotoQcRaw = z.infer<typeof PhotoQcSchema>;
export interface PhotoQc extends PhotoQcRaw {
  passed: boolean;
  /** Reşit olmayan veya çıplaklık: kesin ret, tekrar denenemez. */
  blocked: boolean;
}

const ISSUE_HINTS: Record<PhotoIssue, string> = {
  no_person: 'Fotoğrafta kişi algılanamadı.',
  multiple_people: 'Fotoğrafta yalnızca sen olmalısın.',
  cropped_body: 'Baştan ayağa tüm vücudun görünmeli.',
  arms_covering: 'Kolların gövdeni kapatmasın; hafifçe yana aç.',
  side_pose: 'Kameraya karşıdan, dik dur.',
  dark: 'Daha aydınlık bir ortamda çek.',
  blurry: 'Fotoğraf bulanık; telefonu sabit tut.',
  low_resolution: 'Daha yüksek çözünürlüklü bir fotoğraf kullan.',
  minor: 'Bu fotoğraf kullanılamaz.',
  nudity: 'Bu fotoğraf kullanılamaz.',
};

export function finalizePhotoQc(raw: PhotoQcRaw): PhotoQc {
  const issues = new Set<PhotoIssue>(raw.issues);
  if (!raw.appearsAdult) issues.add('minor');
  if (raw.nudity) issues.add('nudity');
  if (!raw.singlePerson) issues.add(raw.issues.includes('no_person') ? 'no_person' : 'multiple_people');
  if (!raw.fullBodyVisible) issues.add('cropped_body');
  if (!raw.armsClearOfTorso) issues.add('arms_covering');
  if (!raw.frontFacing) issues.add('side_pose');
  if (!raw.lightingOk) issues.add('dark');
  if (!raw.sharp) issues.add('blurry');
  const blocked = issues.has('minor') || issues.has('nudity');
  const passed = !blocked && issues.size === 0;
  const fallbackHint = blocked
    ? ISSUE_HINTS.minor
    : [...issues].map((i) => ISSUE_HINTS[i]).slice(0, 2).join(' ');
  const hint = blocked ? ISSUE_HINTS.minor : truncate(raw.hintTr, 200) || fallbackHint;
  return { ...raw, issues: [...issues], hintTr: passed ? truncate(raw.hintTr, 200) || 'Fotoğraf uygun.' : hint, passed, blocked };
}

export const SelfieQcSchema = z.object({
  singleFace: z.boolean(),
  faceClear: z.boolean(),
  appearsAdult: z.boolean(),
  hintTr: z.string(),
});
export type SelfieQcRaw = z.infer<typeof SelfieQcSchema>;
export interface SelfieQc extends SelfieQcRaw {
  passed: boolean;
  blocked: boolean;
}

export function finalizeSelfieQc(raw: SelfieQcRaw): SelfieQc {
  const blocked = !raw.appearsAdult;
  const passed = !blocked && raw.singleFace && raw.faceClear;
  const hintTr = blocked
    ? 'Bu fotoğraf kullanılamaz.'
    : passed
      ? 'Selfie uygun.'
      : truncate(raw.hintTr, 200) || 'Yüzünün net göründüğü, yalnızca senin olduğun bir selfie çek.';
  return { ...raw, hintTr, passed, blocked };
}

export const GARMENT_CATEGORIES = ['tops', 'bottoms', 'one-pieces', 'dresses', 'shoes', 'other'] as const;
export type GarmentCategory = (typeof GARMENT_CATEGORIES)[number];
export const GARMENT_PHOTO_TYPES = ['flat-lay', 'model', 'mannequin', 'screenshot'] as const;
export type GarmentPhotoType = (typeof GARMENT_PHOTO_TYPES)[number];

export const GarmentAnalysisSchema = z.object({
  isGarment: z.boolean(),
  category: z.enum(GARMENT_CATEGORIES),
  garmentPhotoType: z.enum(GARMENT_PHOTO_TYPES),
  dominantColorHex: z.string(),
  colorNameTr: z.string(),
  fabricGuess: z.string(),
  titleTr: z.string(),
  descriptionTr: z.string(),
  isIsolated: z.boolean(),
  confidence: z.number(),
});
export type GarmentAnalysisRaw = z.infer<typeof GarmentAnalysisSchema>;
export interface GarmentAnalysis extends GarmentAnalysisRaw {
  tryonSupported: boolean;
}

export function isTryOnCategory(category: string): boolean {
  return category === 'tops' || category === 'bottoms' || category === 'one-pieces' || category === 'dresses';
}

export function tryonCategory(category: string): TryOnCategory {
  switch (category) {
    case 'tops':
      return 'tops';
    case 'bottoms':
      return 'bottoms';
    case 'one-pieces':
    case 'dresses':
      return 'one-pieces';
    default:
      return 'auto';
  }
}

export function providerPhotoType(type: string): ProviderPhotoType {
  if (type === 'flat-lay') return 'flat-lay';
  if (type === 'model') return 'model';
  return 'auto';
}

export function normalizeHex(value: string): string {
  const m = /^#?([0-9a-fA-F]{6}|[0-9a-fA-F]{3})$/.exec(value.trim());
  if (!m) return '#808080';
  const hex = m[1]!;
  const full = hex.length === 3 ? hex.split('').map((c) => c + c).join('') : hex;
  return `#${full.toLowerCase()}`;
}

export function finalizeGarment(raw: GarmentAnalysisRaw): GarmentAnalysis {
  return {
    ...raw,
    dominantColorHex: normalizeHex(raw.dominantColorHex),
    colorNameTr: truncate(raw.colorNameTr, 30),
    fabricGuess: truncate(raw.fabricGuess, 40),
    titleTr: truncate(raw.titleTr, 40) || 'Kıyafet',
    descriptionTr: truncate(raw.descriptionTr, 160),
    confidence: clamp01(raw.confidence),
    tryonSupported: raw.isGarment && isTryOnCategory(raw.category),
  };
}

export const StyleAdviceSchema = z.object({
  fitTr: z.string(),
  sizeAdviceTr: z.string(),
  tipsTr: z.array(z.string()),
  occasionTr: z.string(),
  confidence: z.number(),
});
export type StyleAdviceRaw = z.infer<typeof StyleAdviceSchema>;
export type StyleAdvice = StyleAdviceRaw;

export function finalizeStyleAdvice(raw: StyleAdviceRaw): StyleAdvice {
  return {
    fitTr: truncate(raw.fitTr, 240),
    sizeAdviceTr: truncate(raw.sizeAdviceTr, 200),
    tipsTr: raw.tipsTr.map((t) => truncate(t, 140)).filter(Boolean).slice(0, 3),
    occasionTr: truncate(raw.occasionTr, 120),
    confidence: clamp01(raw.confidence),
  };
}

export function truncate(value: string, max: number): string {
  const v = (value ?? '').replace(/\s+/g, ' ').trim();
  return v.length <= max ? v : `${v.slice(0, max - 1).trimEnd()}…`;
}

function clamp01(n: number): number {
  if (!Number.isFinite(n)) return 0;
  return Math.max(0, Math.min(1, n));
}
