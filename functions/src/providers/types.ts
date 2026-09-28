import type { GarmentAnalysis, PhotoQc, SelfieQc, StyleAdvice } from '../ai/schemas.js';

export type ImageMime = 'image/jpeg' | 'image/png' | 'image/webp';

export interface ImageBuf {
  data: Buffer;
  mime: ImageMime;
}

export type TryOnCategory = 'tops' | 'bottoms' | 'one-pieces' | 'auto';
export type ProviderPhotoType = 'flat-lay' | 'model' | 'auto';
export type TryOnChoice = 'fashn' | 'vertex' | 'gemini' | 'both';
export type Model3DChoice = 'trellis2' | 'trellis' | 'hunyuan' | 'tripo';
export type SegmentationChoice = 'gemini' | 'birefnet';
export type ViewAngle = 'side' | 'back';
export type BodyType = 'slim' | 'average' | 'athletic' | 'curvy' | 'plus';
export type Gender = 'female' | 'male' | 'unspecified';

export interface TryOnInput {
  person: ImageBuf;
  garment: ImageBuf;
  /** Daha önce arka planı silinmiş kıyafet (PNG, alfa). Vertex için tekrar kullanılır. */
  garmentIsolated?: ImageBuf | null;
  category: TryOnCategory;
  garmentPhotoType: ProviderPhotoType;
  numSamples: number;
  seed?: number;
  mode?: 'performance' | 'balanced' | 'quality';
}

export interface TaggedImage {
  provider: string;
  image: ImageBuf;
}

export interface TryOnOutput {
  images: TaggedImage[];
  costUsd: number;
  durationMs: number;
  /** Sağlayıcı kıyafeti izole ettiyse (Vertex yolu) önbelleğe alınmak üzere döner. */
  garmentIsolated?: ImageBuf;
  failures?: Array<{ provider: string; message: string }>;
}

export interface TryOnProvider {
  readonly id: string;
  readonly available: boolean;
  run(input: TryOnInput): Promise<TryOnOutput>;
}

export interface SegmentationProvider {
  readonly id: string;
  readonly available: boolean;
  /** Arka planı şeffaf PNG döner. */
  removeBackground(img: ImageBuf): Promise<ImageBuf>;
}

export interface MultiViewProvider {
  readonly id: string;
  readonly available: boolean;
  generateView(front: ImageBuf, angle: ViewAngle): Promise<ImageBuf>;
}

export interface AvatarParams {
  heightCm: number;
  weightKg: number;
  bodyType: BodyType;
  gender: Gender;
}

export interface AvatarProvider {
  readonly id: string;
  readonly available: boolean;
  generateStudioAvatar(selfie: ImageBuf, params: AvatarParams, attempt: number): Promise<ImageBuf>;
}

export interface Model3DResult {
  glb: Buffer;
  preview?: ImageBuf;
  costUsd: number;
  durationMs: number;
}

export interface Model3DProvider {
  readonly id: string;
  readonly available: boolean;
  /** true ise pipeline önce segmentasyon yapar; false ise sağlayıcı arka planı kendisi siler. */
  readonly needsIsolatedInput: boolean;
  generate(img: ImageBuf): Promise<Model3DResult>;
}

export interface StyleContext {
  garmentTitleTr?: string | null;
  garmentCategory?: string | null;
  colorNameTr?: string | null;
  fabricGuess?: string | null;
  heightCm?: number | null;
  weightKg?: number | null;
  bodyType?: string | null;
}

export interface VisionAnalyzer {
  readonly id: string;
  readonly available: boolean;
  checkPhoto(img: ImageBuf): Promise<PhotoQc>;
  checkSelfie(img: ImageBuf): Promise<SelfieQc>;
  analyzeGarment(img: ImageBuf): Promise<GarmentAnalysis>;
  styleAdvice(result: ImageBuf, ctx: StyleContext): Promise<StyleAdvice>;
}

export interface ProviderSet {
  tryOn(choice: TryOnChoice): TryOnProvider;
  segmentation(): SegmentationProvider;
  multiView(): MultiViewProvider;
  avatar(): AvatarProvider;
  model3d(choice: Model3DChoice): Model3DProvider;
  vision(): VisionAnalyzer;
}
