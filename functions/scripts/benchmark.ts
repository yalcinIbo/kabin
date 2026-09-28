/**
 * FASHN ve Vertex try-on sağlayıcılarını aynı çiftlerle karşılaştırır; yan yana HTML rapor üretir.
 * Firebase gerektirmez.
 *
 *   Kuru çalışma (sahte sağlayıcı, anahtarsız):  npm run benchmark -- --mock --samples
 *   Gerçek:  FAL_KEY=... VERTEX_PROJECT_ID=kabin-app-2026 npm run benchmark -- --pairs benchmark/pairs.json
 *            (Vertex için: gcloud auth application-default login)
 *
 * pairs.json: [{ "id": "p1", "photo": "photos/ayse.jpg", "garment": "garments/elbise.jpg",
 *               "category": "one-pieces", "garmentPhotoType": "flat-lay" }]  (yollar benchmark/ klasörüne göre)
 */
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, join, relative, resolve } from 'node:path';
import sharp from 'sharp';
import { normalizeJpeg, toJpeg } from '../src/lib/imaging.js';
import { renderReport, type ReportRow } from '../src/benchmark/report.js';
import { runPair } from '../src/benchmark/runner.js';
import { createProviders, parseMockList } from '../src/providers/factory.js';
import type { ProviderPhotoType, TryOnCategory } from '../src/providers/types.js';
import { parseArgs } from './args.js';

interface PairSpec {
  id: string;
  photo: string;
  garment: string;
  category: TryOnCategory;
  garmentPhotoType: ProviderPhotoType;
}

const args = parseArgs();
const root = resolve(import.meta.dirname, '../benchmark');
const providerIds = String(args.providers ?? 'fashn,vertex')
  .split(',')
  .map((s) => s.trim())
  .filter((s): s is 'fashn' | 'vertex' | 'gemini' => s === 'fashn' || s === 'vertex' || s === 'gemini');
if (providerIds.length === 0) throw new Error('--providers fashn,vertex,gemini');

async function makeSamples(): Promise<PairSpec[]> {
  const dir = join(root, 'samples');
  await mkdir(dir, { recursive: true });
  const person = await sharp({ create: { width: 600, height: 1000, channels: 3, background: '#e7e5e4' } })
    .composite([{ input: Buffer.from('<svg width="600" height="1000"><circle cx="300" cy="150" r="70" fill="#d6a77a"/><rect x="210" y="240" width="180" height="360" rx="30" fill="#9ca3af"/><rect x="220" y="590" width="70" height="380" fill="#374151"/><rect x="310" y="590" width="70" height="380" fill="#374151"/></svg>') }])
    .jpeg()
    .toBuffer();
  await writeFile(join(dir, 'person.jpg'), person);
  const specs: PairSpec[] = [];
  for (const [id, color, category] of [['tshirt', '#1e3a8a', 'tops'], ['skirt', '#b91c1c', 'bottoms']] as const) {
    const g = await sharp({ create: { width: 500, height: 500, channels: 3, background: '#ffffff' } })
      .composite([{ input: Buffer.from(`<svg width="500" height="500"><rect x="100" y="80" width="300" height="340" rx="40" fill="${color}"/></svg>`) }])
      .jpeg()
      .toBuffer();
    await writeFile(join(dir, `${id}.jpg`), g);
    specs.push({ id, photo: 'samples/person.jpg', garment: `samples/${id}.jpg`, category, garmentPhotoType: 'flat-lay' });
  }
  return specs;
}

const pairs: PairSpec[] = args.samples
  ? await makeSamples()
  : (JSON.parse(await readFile(resolve(String(args.pairs ?? join(root, 'pairs.json'))), 'utf8')) as PairSpec[]);

const set = createProviders({
  falKey: process.env.FAL_KEY ?? '',
  geminiKey: process.env.GEMINI_API_KEY ?? '',
  hfToken: process.env.HF_TOKEN ?? '',
  tryon: 'fashn',
  model3d: 'trellis2',
  segmentation: process.env.SEGMENTATION_PROVIDER === 'birefnet' ? 'birefnet' : 'gemini',
  vertex: {
    projectId: process.env.VERTEX_PROJECT_ID ?? process.env.GCLOUD_PROJECT ?? '',
    location: process.env.VERTEX_LOCATION ?? 'us-central1',
    model: process.env.VERTEX_TRYON_MODEL ?? 'virtual-try-on-001',
  },
  gemini: { visionModel: 'gemini-3.8-flash', imageModel: 'gemini-3.1-flash-image' },
  mock: parseMockList(args.mock ? 'all' : 'none'),
});
const tryOnProviders = providerIds.map((id) => set.tryOn(id));
for (const [i, p] of tryOnProviders.entries()) {
  if (!p.available) console.warn(`⚠ ${providerIds[i]} yapılandırılmamış (anahtar/proje eksik); hata olarak raporlanacak.`);
}

const runId = new Date().toISOString().replace(/[:.]/g, '-');
const outDir = join(root, 'out', runId);
await mkdir(outDir, { recursive: true });
const rows: ReportRow[] = [];
const summary: unknown[] = [];

for (const pair of pairs) {
  process.stdout.write(`• ${pair.id} … `);
  const pairDir = join(outDir, pair.id);
  await mkdir(pairDir, { recursive: true });
  const person = await normalizeJpeg(await readFile(resolve(root, pair.photo)));
  const garment = await normalizeJpeg(await readFile(resolve(root, pair.garment)));
  await writeFile(join(pairDir, 'person.jpg'), person.data);
  await writeFile(join(pairDir, 'garment.jpg'), garment.data);
  const runs = await runPair(tryOnProviders, { person, garment, category: pair.category, garmentPhotoType: pair.garmentPhotoType, seed: 42 });
  const cells: ReportRow['cells'] = [];
  let isolatedSrc: string | undefined;
  for (const [i, r] of runs.entries()) {
    const key = providerIds[i]!;
    if (r.garmentIsolated) {
      const file = join(pairDir, 'garment_isolated.png');
      await writeFile(file, r.garmentIsolated.data);
      isolatedSrc = relative(outDir, file);
    }
    if (r.ok && r.image) {
      const file = join(pairDir, `${key}.jpg`);
      await writeFile(file, (await toJpeg(r.image)).data);
      cells.push({ provider: key, src: relative(outDir, file), ms: r.ms, costUsd: r.costUsd });
    } else {
      cells.push({ provider: key, ms: r.ms, costUsd: 0, error: r.error ?? 'hata' });
    }
  }
  rows.push({
    pairId: pair.id,
    personSrc: relative(outDir, join(pairDir, 'person.jpg')),
    garmentSrc: relative(outDir, join(pairDir, 'garment.jpg')),
    ...(isolatedSrc ? { garmentIsolatedSrc: isolatedSrc } : {}),
    category: pair.category,
    cells,
  });
  summary.push({ pair: pair.id, results: runs.map((r, i) => ({ provider: providerIds[i], actual: r.provider, ok: r.ok, ms: r.ms, costUsd: r.costUsd, error: r.error ?? null })) });
  console.log(runs.map((r, i) => `${providerIds[i]}:${r.ok ? `${(r.ms / 1000).toFixed(1)}sn` : 'HATA'}`).join('  '));
}

await writeFile(join(outDir, 'summary.json'), JSON.stringify({ runId, providers: providerIds, pairs: summary }, null, 2));
const reportPath = join(outDir, 'index.html');
await writeFile(reportPath, renderReport(runId, providerIds, rows));
await mkdir(dirname(reportPath), { recursive: true });
console.log(`\n✔ Rapor: ${reportPath}`);
