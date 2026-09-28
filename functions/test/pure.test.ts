import sharp from 'sharp';
import { describe, expect, it } from 'vitest';
import { buildTexturedCardGlb, makeNonMetallic, parseGlb } from '../src/lib/glb.js';
import { finalizeGarment, finalizePhotoQc, normalizeHex, providerPhotoType, tryonCategory } from '../src/ai/schemas.js';
import { renderReport } from '../src/benchmark/report.js';
import { runPair } from '../src/benchmark/runner.js';
import { mergePricing, DEFAULT_PRICING } from '../src/config/pricing.js';
import { FakeModel3DProvider, FakeTryOnProvider } from '../src/providers/fake.js';
import { parseMockList } from '../src/providers/factory.js';
import { JobError } from '../src/lib/job_error.js';
import { CompositeTryOnProvider } from '../src/providers/tryon/composite.js';
import { FashnTryOnProvider } from '../src/providers/tryon/fashn.js';
import { HfTrellis3DProvider, mapTrellisError, type GradioLike } from '../src/providers/model3d/hf_trellis.js';
import { createProviders } from '../src/providers/factory.js';
import { HfTrellis2Provider, extractTrellis2Preview } from '../src/providers/model3d/hf_trellis2.js';
import { VertexTryOnProvider, buildVertexRequest, vertexEndpoint } from '../src/providers/tryon/vertex.js';
import type { FalLike } from '../src/providers/fal.js';
import type { ImageBuf, SegmentationProvider, TryOnInput, TryOnProvider } from '../src/providers/types.js';
import { makeJpeg } from './helpers.js';

async function img(w = 300, h = 400, color = '#999999'): Promise<ImageBuf> {
  return { data: await makeJpeg(w, h, color), mime: 'image/jpeg' };
}

async function input(): Promise<TryOnInput> {
  return { person: await img(), garment: await img(200, 200, '#2563eb'), category: 'tops', garmentPhotoType: 'flat-lay', numSamples: 1 };
}

describe('GLB üretici', () => {
  it('geçerli glTF 2.0 ikili dosyası üretir', async () => {
    const tex = await makeJpeg(60, 80, '#ff0000');
    const glb = buildTexturedCardGlb({ data: tex, mime: 'image/jpeg', width: 60, height: 80 });
    const parsed = parseGlb(glb);
    expect(parsed.version).toBe(2);
    expect(parsed.binLength % 4).toBe(0);
    const json = parsed.json as { accessors: Array<{ count: number }>; images: Array<{ mimeType: string }>; bufferViews: Array<{ byteOffset: number; byteLength: number }> };
    expect(json.accessors[0]!.count).toBe(24);
    expect(json.accessors[3]!.count).toBe(36);
    expect(json.images[0]!.mimeType).toBe('image/jpeg');
    const imageView = json.bufferViews[4]!;
    expect(imageView.byteLength).toBe(tex.length);
    expect(imageView.byteOffset + imageView.byteLength).toBeLessThanOrEqual(parsed.binLength);
  });

  it('sahte 3D sağlayıcı GLB ve önizleme döner', async () => {
    const res = await new FakeModel3DProvider('fake-3d', 0).generate(await img());
    expect(parseGlb(res.glb).version).toBe(2);
    expect(res.preview?.mime).toBe('image/jpeg');
  });
});

describe('Gemini çıktı normalizasyonu', () => {
  it('fotoğraf kalite kontrolünde sorunları birleştirir ve reşit olmayanı engeller', () => {
    const ok = finalizePhotoQc({
      singlePerson: true, fullBodyVisible: true, armsClearOfTorso: true, frontFacing: true,
      lightingOk: true, sharp: true, appearsAdult: true, nudity: false, issues: [], hintTr: 'Güzel.',
    });
    expect(ok.passed).toBe(true);
    const cropped = finalizePhotoQc({ ...ok, fullBodyVisible: false, hintTr: '' });
    expect(cropped.passed).toBe(false);
    expect(cropped.issues).toContain('cropped_body');
    expect(cropped.hintTr).toMatch(/Baştan ayağa/);
    const minor = finalizePhotoQc({ ...ok, appearsAdult: false });
    expect(minor.blocked).toBe(true);
    expect(minor.hintTr).toBe('Bu fotoğraf kullanılamaz.');
  });

  it('kıyafet analizini kısaltır, rengi normalize eder ve desteği hesaplar', () => {
    const g = finalizeGarment({
      isGarment: true, category: 'dresses', garmentPhotoType: 'screenshot', dominantColorHex: 'ABC',
      colorNameTr: 'mavi', fabricGuess: 'keten', titleTr: 'Çok uzun bir başlık '.repeat(5), descriptionTr: 'x', isIsolated: false, confidence: 3,
    });
    expect(g.dominantColorHex).toBe('#aabbcc');
    expect(g.titleTr.length).toBeLessThanOrEqual(40);
    expect(g.confidence).toBe(1);
    expect(g.tryonSupported).toBe(true);
    expect(finalizeGarment({ ...g, category: 'shoes' }).tryonSupported).toBe(false);
    expect(normalizeHex('bozuk')).toBe('#808080');
    expect(tryonCategory('dresses')).toBe('one-pieces');
    expect(providerPhotoType('mannequin')).toBe('auto');
  });

  it('fiyatlandırma varsayılanlarla birleşir', () => {
    expect(mergePricing(undefined)).toEqual(DEFAULT_PRICING);
    const p = mergePricing({ tryon: 2, dailyCaps: { tryon: 3 }, model3d: -1 });
    expect(p.tryon).toBe(2);
    expect(p.dailyCaps.tryon).toBe(3);
    expect(p.model3d).toBe(DEFAULT_PRICING.model3d);
  });

  it('MOCK_PROVIDERS listesi çözülür', () => {
    expect(parseMockList('all').size).toBe(5);
    expect(parseMockList('none').size).toBe(0);
    expect([...parseMockList('tryon, model3d, bogus')]).toEqual(['tryon', 'model3d']);
  });
});

describe('FASHN sağlayıcı', () => {
  it('fal girdisini doğru kurar ve sonucu indirir', async () => {
    const out = await makeJpeg(100, 150, '#00ff00');
    const calls: Array<{ endpoint: string; input: Record<string, unknown> }> = [];
    const fake: FalLike = {
      storage: { upload: async () => 'https://fal.test/in.jpg' },
      subscribe: async (endpoint, options) => {
        calls.push({ endpoint, input: options.input });
        return { data: { images: [{ url: 'data:image/jpeg;base64,' + out.toString('base64') }] }, requestId: 'r1' };
      },
    };
    const p = new FashnTryOnProvider({ falKey: '', client: fake });
    const res = await p.run({ ...(await input()), category: 'one-pieces', garmentPhotoType: 'model', numSamples: 9 });
    expect(calls[0]!.endpoint).toBe('fal-ai/fashn/tryon/v1.6');
    expect(calls[0]!.input).toMatchObject({ category: 'one-pieces', garment_photo_type: 'model', num_samples: 4, moderation_level: 'conservative' });
    expect(res.images[0]!.provider).toBe('fashn');
    expect(res.images[0]!.image.mime).toBe('image/jpeg');
    expect(res.costUsd).toBeCloseTo(0.075);
  });

  it('anahtar yoksa yapılandırma hatası verir', async () => {
    await expect(new FashnTryOnProvider({ falKey: '' }).run(await input())).rejects.toMatchObject({ code: 'provider-not-configured' });
  });
});

describe('Vertex sağlayıcı', () => {
  it('istek gövdesini ve uç noktayı doğru kurar', async () => {
    const body = buildVertexRequest(await img(), await img(), 7, 3);
    expect(body.parameters.sampleCount).toBe(4);
    expect(body.parameters.seed).toBe(3);
    expect(body.instances[0]!.productImages).toHaveLength(1);
    expect(vertexEndpoint({ projectId: 'p', location: 'us-central1', model: 'virtual-try-on-001' })).toBe(
      'https://us-central1-aiplatform.googleapis.com/v1/projects/p/locations/us-central1/publishers/google/models/virtual-try-on-001:predict',
    );
  });

  it('izole değilse önce segmentasyon yapar, sonucu çözer', async () => {
    let segmented = 0;
    const segmentation: SegmentationProvider = {
      id: 's',
      available: true,
      removeBackground: async (i) => {
        segmented++;
        return { data: await sharp(i.data).ensureAlpha().png().toBuffer(), mime: 'image/png' };
      },
    };
    const result = await makeJpeg(80, 120, '#ff00ff');
    let sentBody: { instances: Array<{ productImages: Array<{ image: { bytesBase64Encoded: string } }> }> } | null = null;
    const fetchImpl = (async (_url: string, init: { body: string }) => {
      sentBody = JSON.parse(init.body);
      return new Response(JSON.stringify({ predictions: [{ bytesBase64Encoded: result.toString('base64'), mimeType: 'image/jpeg' }] }), { status: 200 });
    }) as unknown as typeof fetch;
    const p = new VertexTryOnProvider({ projectId: 'p', location: 'us-central1', model: 'virtual-try-on-001', segmentation, getAccessToken: async () => 't', fetchImpl });
    const res = await p.run(await input());
    expect(segmented).toBe(1);
    expect(res.garmentIsolated?.mime).toBe('image/png');
    expect(res.images[0]!.image.data.equals(result)).toBe(true);
    const garmentSent = Buffer.from(sentBody!.instances[0]!.productImages[0]!.image.bytesBase64Encoded, 'base64');
    expect(garmentSent[0]).toBe(0xff); // beyaza oturtulmuş JPEG
  });

  it('403 yanıtını yapılandırma hatasına çevirir', async () => {
    const fetchImpl = (async () => new Response('denied', { status: 403 })) as unknown as typeof fetch;
    const seg: SegmentationProvider = { id: 's', available: true, removeBackground: async (i) => i };
    const p = new VertexTryOnProvider({ projectId: 'p', location: 'l', model: 'm', segmentation: seg, getAccessToken: async () => 't', fetchImpl });
    await expect(p.run(await input())).rejects.toMatchObject({ code: 'provider-not-configured' });
  });
});

describe('Bileşik sağlayıcı ve benchmark', () => {
  const failing: TryOnProvider = { id: 'bad', available: true, run: async () => { throw new JobError('provider-failed', 'x', 'boom'); } };

  it('bir sağlayıcı düşerse diğerinin sonucunu döner', async () => {
    const res = await new CompositeTryOnProvider([new FakeTryOnProvider('a', 0), failing]).run(await input());
    expect(res.images.map((i) => i.provider)).toEqual(['a']);
    expect(res.failures?.[0]?.provider).toBe('bad');
  });

  it('hepsi düşerse hata fırlatır', async () => {
    await expect(new CompositeTryOnProvider([failing]).run(await input())).rejects.toBeInstanceOf(JobError);
  });

  it('runPair sağlayıcıları ayrı ölçer ve rapor üretir', async () => {
    const i = await input();
    const runs = await runPair([new FakeTryOnProvider('fake-fashn', 0), failing], i);
    expect(runs[0]!.ok).toBe(true);
    expect(runs[1]!.ok).toBe(false);
    const html = renderReport('r1', ['fake-fashn', 'bad'], [
      { pairId: 'p<1>', personSrc: 'a.jpg', garmentSrc: 'b.jpg', category: 'tops', cells: runs.map((r) => ({ provider: r.provider, src: 'x.jpg', ms: r.ms, costUsd: r.costUsd, ...(r.error ? { error: r.error } : {}) })) },
    ]);
    expect(html).toContain('p&lt;1&gt;');
    expect(html).toContain('1/1 başarılı');
    expect(html).toContain('prefers-color-scheme:dark');
  });
});

describe('fal hata eşleme', () => {
  it('yükleme adımındaki 403 bakiye hatası yapılandırma hatasına çevrilir', async () => {
    const { ApiError } = await import('@fal-ai/client');
    const fake: FalLike = {
      storage: { upload: async () => { throw new ApiError({ message: 'Forbidden', status: 403, body: { detail: 'Exhausted balance' }, requestId: 'r' }); } },
      subscribe: async () => ({ data: {}, requestId: 'r' }),
    };
    const err = await new FashnTryOnProvider({ falKey: '', client: fake }).run(await input()).catch((e) => e);
    expect(err).toMatchObject({ code: 'provider-not-configured' });
    expect(err.detail).toContain('Exhausted balance');
  });
});

describe('TRELLIS 3D sağlayıcı (Hugging Face)', () => {
  const glbBytes = Buffer.concat([Buffer.from('glTF'), Buffer.alloc(16)]);

  function fakeClient(calls: string[], fail?: { endpoint: string; error: unknown }): GradioLike {
    return {
      predict: async (endpoint) => {
        calls.push(endpoint);
        if (fail && fail.endpoint === endpoint) throw fail.error;
        if (endpoint === '/preprocess_image') return { data: [{ url: 'https://space/pre.png', path: '/tmp/pre.png' }] };
        if (endpoint === '/generate_and_extract_glb') return { data: [{ video: {} }, { url: 'https://space/a.glb' }, { url: 'https://space/b.glb' }] };
        return { data: [] };
      },
    };
  }

  it('oturum açar, ön işler, GLB indirir; segmentasyon istemez', async () => {
    const calls: string[] = [];
    const fetched: Array<{ url: string; token?: string }> = [];
    const png = await sharp({ create: { width: 40, height: 40, channels: 4, background: '#00000000' } }).png().toBuffer();
    const p = new HfTrellis3DProvider({
      hfToken: 'hf_test',
      connect: async (_space, token) => {
        expect(token).toBe('hf_test');
        return fakeClient(calls);
      },
      fetchFile: async (url, token) => {
        fetched.push({ url, token });
        return url.endsWith('.glb') ? glbBytes : png;
      },
    });
    expect(p.needsIsolatedInput).toBe(false);
    const out = await p.generate(await img());
    expect(calls).toEqual(['/start_session', '/preprocess_image', '/generate_and_extract_glb']);
    expect(fetched[0]).toEqual({ url: 'https://space/b.glb', token: 'hf_test' });
    expect(out.glb.subarray(0, 4).toString()).toBe('glTF');
    expect(out.preview?.mime).toBe('image/png');
    expect(out.costUsd).toBe(0);
  });

  it('ZeroGPU kota hatasını tekrar denenmeyen TR mesaja çevirir', async () => {
    const quota = Object.assign(new Error('You have exceeded your ZeroGPU quota'), { title: 'ZeroGPU quota exceeded', stage: 'error' });
    const p = new HfTrellis3DProvider({ connect: async () => fakeClient([], { endpoint: '/generate_and_extract_glb', error: quota }), fetchFile: async () => glbBytes });
    const err = await p.generate(await img()).catch((e) => e);
    expect(err).toBeInstanceOf(JobError);
    expect(err.messageTr).toContain('kotası doldu');
    expect(err.retryable).toBe(false);
    expect(mapTrellisError(new Error('fetch failed'), 'bağlantı').retryable).toBe(true);
  });

  it('süre aşımında provider-timeout döner', async () => {
    const slow: GradioLike = { predict: () => new Promise(() => undefined) };
    const p = new HfTrellis3DProvider({ connect: async () => slow, timeoutMs: 20 });
    await expect(p.generate(await img())).rejects.toMatchObject({ code: 'provider-timeout' });
  });

  it('fabrika varsayılan ücretsiz yolu kurar', () => {
    const set = createProviders({
      falKey: '', geminiKey: 'g', hfToken: '', tryon: 'gemini', model3d: 'trellis', segmentation: 'gemini',
      vertex: { projectId: 'p', location: 'us-central1', model: 'virtual-try-on-001' },
      gemini: { visionModel: 'v', imageModel: 'i' }, mock: new Set(),
    });
    expect(set.model3d('trellis2').id).toBe('trellis2');
    expect(set.model3d('trellis').id).toBe('trellis');
    expect(set.model3d('hunyuan').needsIsolatedInput).toBe(true);
    expect(set.segmentation().id).toBe('gemini-isolate');
    expect(set.tryOn('gemini').id).toBe('gemini');
  });
});

describe('TRELLIS.2 3D sağlayıcı (Hugging Face)', () => {
  const glbBytes = Buffer.concat([Buffer.from('glTF'), Buffer.alloc(16)]);

  async function previewHtml(): Promise<string> {
    const person = await sharp({ create: { width: 200, height: 200, channels: 3, background: '#000000' } })
      .composite([{ input: await sharp({ create: { width: 60, height: 140, channels: 3, background: '#c2552d' } }).png().toBuffer(), left: 70, top: 30 }])
      .jpeg()
      .toBuffer();
    const other = await sharp({ create: { width: 10, height: 10, channels: 3, background: '#00ff00' } }).jpeg().toBuffer();
    return `<img id="view-m3-s0" class="previewer-main-image" src="data:image/jpeg;base64,${other.toString('base64')}">` +
      `<img id="view-m3-s4" class="previewer-main-image visible" src="data:image/jpeg;base64,${person.toString('base64')}">`;
  }

  it('oturumda sırayla üretir, ayarları iletir, önden önizlemeyi kırpar', async () => {
    const calls: Array<{ endpoint: string; data: Record<string, unknown> }> = [];
    const html = await previewHtml();
    const client: GradioLike = {
      predict: async (endpoint, data) => {
        calls.push({ endpoint, data });
        if (endpoint === '/preprocess_image') return { data: [{ url: 'https://space/pre.png' }] };
        if (endpoint === '/image_to_3d') return { data: [html] };
        if (endpoint === '/extract_glb') return { data: [{ url: 'https://space/a.glb' }, { url: 'https://space/a.glb' }] };
        return { data: [] };
      },
    };
    const p = new HfTrellis2Provider({ hfToken: 'hf_x', connect: async () => client, fetchFile: async () => glbBytes, settings: { textureSize: 4096 } });
    expect(p.needsIsolatedInput).toBe(false);
    const out = await p.generate(await img());
    expect(calls.map((c) => c.endpoint)).toEqual(['/start_session', '/preprocess_image', '/image_to_3d', '/extract_glb']);
    expect(calls[2]!.data.resolution).toBe('1024');
    expect(calls[3]!.data).toEqual({ decimation_target: 300000, texture_size: 4096 });
    expect(out.glb.subarray(0, 4).toString()).toBe('glTF');
    const meta = await sharp(out.preview!.data).metadata();
    // Siyah fon kırpılır (200 px'ten ~108'e); JPEG kenar gürültüsü birkaç piksel pay bırakır.
    expect(meta.width).toBeGreaterThanOrEqual(60 + 48);
    expect(meta.width).toBeLessThan(130);
    expect(meta.height).toBeGreaterThanOrEqual(140 + 48);
    expect(meta.height).toBeLessThan(200);
  });

  it('önizleme yoksa null döner', () => {
    expect(extractTrellis2Preview('<div>yok</div>')).toBeNull();
  });

  it('kota hatasını TR mesaja çevirir', async () => {
    const quota = Object.assign(new Error('You have exceeded your ZeroGPU quota'), { title: 'ZeroGPU quota exceeded' });
    const client: GradioLike = {
      predict: async (endpoint) => {
        if (endpoint === '/image_to_3d') throw quota;
        return { data: [{ url: 'https://space/pre.png' }] };
      },
    };
    const err = await new HfTrellis2Provider({ connect: async () => client }).generate(await img()).catch((e) => e);
    expect(err.messageTr).toContain('kotası doldu');
    expect(err.detail).toContain('trellis2 /image_to_3d');
  });
});

describe('GLB malzeme düzeltmesi', () => {
  it('metalliği 0 yapar, ikili veriyi korur ve geçerli GLB üretir', async () => {
    const tex = await makeJpeg(60, 80, '#c2552d');
    const glb = buildTexturedCardGlb({ data: tex, mime: 'image/jpeg', width: 60, height: 80 });
    const before = parseGlb(glb);
    const fixed = makeNonMetallic(glb);
    const after = parseGlb(fixed);
    const mats = (after.json as { materials: Array<{ pbrMetallicRoughness: { metallicFactor: number } }> }).materials;
    expect(mats.every((m) => m.pbrMetallicRoughness.metallicFactor === 0)).toBe(true);
    expect(after.binLength).toBe(before.binLength);
    expect(fixed.subarray(fixed.length - before.binLength).equals(glb.subarray(glb.length - before.binLength))).toBe(true);
  });
});
