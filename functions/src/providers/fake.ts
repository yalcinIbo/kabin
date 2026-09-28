import sharp, { type OverlayOptions, type Sharp } from 'sharp';
import { buildTexturedCardGlb } from '../lib/glb.js';
import { dominantColorHex, imageSize, normalizePng } from '../lib/imaging.js';
import {
  finalizeGarment,
  finalizePhotoQc,
  finalizeSelfieQc,
  finalizeStyleAdvice,
  type GarmentAnalysis,
  type PhotoQc,
  type SelfieQc,
  type StyleAdvice,
} from '../ai/schemas.js';
import type {
  AvatarParams,
  AvatarProvider,
  ImageBuf,
  Model3DProvider,
  Model3DResult,
  MultiViewProvider,
  SegmentationProvider,
  StyleContext,
  TryOnInput,
  TryOnOutput,
  TryOnProvider,
  ViewAngle,
  VisionAnalyzer,
} from './types.js';

// Sahte sağlayıcılar: API anahtarı ve maliyet olmadan uçtan uca akışı geliştirmek/test etmek için.
// Çıktılar görsel olarak "TEST" etiketlidir; gerçek sonuç yerine geçmez.

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

function label(text: string, width: number): Buffer {
  const fontSize = Math.max(18, Math.round(width / 18));
  const h = Math.round(fontSize * 1.8);
  const safe = text.replace(/[<>&]/g, '');
  return Buffer.from(
    `<svg width="${width}" height="${h}" xmlns="http://www.w3.org/2000/svg">
      <rect width="100%" height="100%" fill="#111827" fill-opacity="0.72"/>
      <text x="50%" y="62%" font-family="Helvetica, Arial, sans-serif" font-size="${fontSize}" font-weight="700"
        fill="#ffffff" text-anchor="middle">${safe}</text>
    </svg>`,
  );
}

/** sharp'ta `composite` tek sefer uygulanır; tüm katmanlar aynı çağrıda verilmeli. */
async function withLabel(img: Sharp, width: number, text: string, overlays: OverlayOptions[] = []): Promise<ImageBuf> {
  const data = await img
    .composite([...overlays, { input: label(text, width), gravity: 'south' }])
    .jpeg({ quality: 88 })
    .toBuffer();
  return { data, mime: 'image/jpeg' };
}

export class FakeTryOnProvider implements TryOnProvider {
  readonly available = true;

  constructor(readonly id = 'fake', private readonly delayMs = 1200) {}

  async run(input: TryOnInput): Promise<TryOnOutput> {
    const started = Date.now();
    await sleep(this.delayMs);
    const { width, height } = await imageSize(input.person);
    const garmentWidth = Math.max(32, Math.round(width * 0.42));
    const garment = await sharp(input.garment.data)
      .resize({ width: garmentWidth, height: Math.round(height * 0.4), fit: 'inside' })
      .png()
      .toBuffer();
    const meta = await sharp(garment).metadata();
    const top = Math.max(0, Math.round(height * (input.category === 'bottoms' ? 0.5 : 0.22)));
    const left = Math.max(0, Math.round((width - (meta.width ?? garmentWidth)) / 2));
    const image = await withLabel(sharp(input.person.data), width, `TEST · ${this.id.toUpperCase()} TRY-ON`, [{ input: garment, top, left }]);
    return { images: [{ provider: this.id, image }], costUsd: 0, durationMs: Date.now() - started };
  }
}

export class FakeSegmentation implements SegmentationProvider {
  readonly id = 'fake-segmentation';
  readonly available = true;

  async removeBackground(img: ImageBuf): Promise<ImageBuf> {
    return normalizePng(img.data);
  }
}

export class FakeImageProvider implements MultiViewProvider, AvatarProvider {
  readonly id = 'fake-image';
  readonly available = true;

  constructor(private readonly delayMs = 600) {}

  async generateView(front: ImageBuf, angle: ViewAngle): Promise<ImageBuf> {
    await sleep(this.delayMs);
    const { width } = await imageSize(front);
    const base = angle === 'side' ? sharp(front.data).flop() : sharp(front.data).modulate({ brightness: 0.75 });
    return withLabel(base, width, angle === 'side' ? 'TEST · YAN GÖRÜNÜM' : 'TEST · ARKA GÖRÜNÜM');
  }

  async generateStudioAvatar(selfie: ImageBuf, params: AvatarParams): Promise<ImageBuf> {
    await sleep(this.delayMs);
    const width = 768;
    const height = 1024;
    const face = await sharp(selfie.data).resize({ width: 300, height: 300, fit: 'cover' }).png().toBuffer();
    const base = sharp({ create: { width, height, channels: 3, background: '#d1d5db' } });
    return withLabel(base, width, `TEST · AVATAR ${params.heightCm}cm ${params.weightKg}kg`, [
      { input: face, top: 60, left: Math.round((width - 300) / 2) },
    ]);
  }
}

export class FakeModel3DProvider implements Model3DProvider {
  readonly available = true;

  readonly needsIsolatedInput = true;

  constructor(readonly id = 'fake-3d', private readonly delayMs = 1500) {}

  async generate(img: ImageBuf): Promise<Model3DResult> {
    const started = Date.now();
    await sleep(this.delayMs);
    const tex = await sharp(img.data).resize({ width: 768, height: 1024, fit: 'inside' }).flatten({ background: '#ffffff' }).jpeg({ quality: 85 }).toBuffer();
    const size = await imageSize({ data: tex, mime: 'image/jpeg' });
    const glb = buildTexturedCardGlb({ data: tex, mime: 'image/jpeg', width: size.width, height: size.height });
    return { glb, preview: { data: tex, mime: 'image/jpeg' }, costUsd: 0, durationMs: Date.now() - started };
  }
}

export class FakeVisionAnalyzer implements VisionAnalyzer {
  readonly id = 'fake-vision';
  readonly available = true;

  async checkPhoto(img: ImageBuf): Promise<PhotoQc> {
    const { width, height } = await imageSize(img);
    const tooSmall = Math.min(width, height) < 256;
    return finalizePhotoQc({
      singlePerson: true,
      fullBodyVisible: true,
      armsClearOfTorso: true,
      frontFacing: true,
      lightingOk: true,
      sharp: !tooSmall,
      appearsAdult: true,
      nudity: false,
      issues: tooSmall ? ['low_resolution'] : [],
      hintTr: tooSmall ? 'Daha yüksek çözünürlüklü bir fotoğraf kullan.' : 'Fotoğraf uygun (test modu).',
    });
  }

  async checkSelfie(): Promise<SelfieQc> {
    return finalizeSelfieQc({ singleFace: true, faceClear: true, appearsAdult: true, hintTr: 'Selfie uygun (test modu).' });
  }

  async analyzeGarment(img: ImageBuf): Promise<GarmentAnalysis> {
    const hex = await dominantColorHex(img);
    return finalizeGarment({
      isGarment: true,
      category: 'tops',
      garmentPhotoType: 'flat-lay',
      dominantColorHex: hex,
      colorNameTr: 'test rengi',
      fabricGuess: 'pamuklu (tahmin)',
      titleTr: 'Test kıyafeti',
      descriptionTr: 'Test modunda üretilmiş örnek analiz.',
      isIsolated: false,
      confidence: 0.5,
    });
  }

  async styleAdvice(_result: ImageBuf, ctx: StyleContext): Promise<StyleAdvice> {
    return finalizeStyleAdvice({
      fitTr: `${ctx.garmentTitleTr ?? 'Kıyafet'} üzerinde dengeli duruyor (test modu).`,
      sizeAdviceTr: ctx.heightCm ? `${ctx.heightCm} cm boy için normal beden uygun görünüyor (tahmin).` : 'Beden için ölçülerini profilden ekleyebilirsin.',
      tipsTr: ['Düz renk bir altla dengele.', 'Beyaz spor ayakkabı ile günlük kombin yap.'],
      occasionTr: 'günlük',
      confidence: 0.3,
    });
  }
}
