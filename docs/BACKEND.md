# Kabin — Backend (Cloud Functions)

Bölge `europe-west1`, Node 22, TypeScript (ESM), firebase-functions 7.

## Fonksiyonlar
| Ad | Tür | Görev |
|---|---|---|
| `checkPhoto` | callable | Boydan fotoğraf kalite kontrolü (Gemini) → `ready` / `rejected` |
| `analyzeGarment` | callable | Kıyafet analizi (Gemini): kategori, renk, kumaş, başlık |
| `requestTryOn` | callable | Transaction: kredi + günlük sınır + belge kontrolü → `tryons/{id}` `queued` |
| `requestModel3D` | callable | Tamamlanan denemeden 3D işi (aynı deneme için tekrar ücret yok) |
| `generateAvatar` | callable | Selfie + ölçüler → `photos/{id}` (`source=generated`) |
| `deleteMyAccount` | callable | KVKK: son 10 dk içinde yeniden giriş şartıyla tüm verileri siler |
| `runBenchmark` | callable (admin) | FASHN × Vertex karşılaştırma koşusu |
| `onUserCreated` | Firestore | Hoş geldin kredisi (`ledger/welcome`, idempotent) |
| `onTryOnCreated` / `onModel3DCreated` / `onPhotoCreated` | Firestore | `runJob` ile işleri yürütür (540 sn, 1 GiB) |
| `onBenchmarkPairCreated` | Firestore | Karşılaştırma çiftini işler |
| `on{Photo,Garment,TryOn,Model3D}Deleted` | Firestore | Storage klasörünü temizler |
| `sweepJobs` | zamanlanmış (10 dk) | Takılan işleri `failed` yapar + iade |
| `onAuthUserDeleted` | Auth (v1) | Konsoldan silinen hesapların verilerini temizler |

## İş durum makinesi (`src/jobs/runner.ts`)
```
queued ─claim (transaction)→ processing ─ok→ done
                                  └─hata / süre aşımı→ failed + refundJob (idempotent)
```
- `claimJob` yalnızca `queued` belgeyi alır → tetikleyici iki kez gelse de iş bir kez yapılır.
- `leaseUntil`: kuyrukta 15 dk, işlenirken 9,5 dk. Süpürücü süresi dolanı iade eder.
- Kısmi iade: çoklu açı tamamen başarısızsa yalnız o kısmın kredisi (`refund_{jobId}_multiview`).

## Sağlayıcılar (`src/providers/`)
| Arayüz | Gerçek | Sahte (MOCK) |
|---|---|---|
| `TryOnProvider` | `GeminiTryOnProvider` (varsayılan, `gemini-3.1-flash-image`), `FashnTryOnProvider` (fal.ai `fal-ai/fashn/tryon/v1.6`), `VertexTryOnProvider` (`virtual-try-on-001`), `CompositeTryOnProvider` (FASHN + Vertex) | `FakeTryOnProvider` |
| `SegmentationProvider` | `GeminiSegmentation` (varsayılan; kıyafeti düz beyaz zemine alır), `FalBirefnetSegmentation` (`fal-ai/birefnet`, şeffaf PNG) | `FakeSegmentation` |
| `MultiViewProvider` / `AvatarProvider` | `GeminiImageProvider` (`gemini-3.1-flash-image`) | `FakeImageProvider` |
| `Model3DProvider` | `HfTrellis2Provider` (varsayılan; Hugging Face `microsoft/TRELLIS.2`, MIT, PBR doku, ücretsiz ZeroGPU kotası, arka planı kendisi siler), `HfTrellis3DProvider` (eski TRELLIS, daha düşük kalite), `FalHunyuan3DProvider` (`fal-ai/hunyuan3d/v2`), `FalTripo3DProvider` | `FakeModel3DProvider` (dokulu kart GLB) |
| `VisionAnalyzer` | `GeminiVisionAnalyzer` (`gemini-3.8-flash`, JSON şema) | `FakeVisionAnalyzer` |

Seçim: `.env` → `TRYON_PROVIDER=gemini|fashn|vertex|both`, `MODEL3D_PROVIDER=trellis2|trellis|hunyuan|tripo`, `SEGMENTATION_PROVIDER=gemini|birefnet`, `MOCK_PROVIDERS=none|all|tryon,vision,...`.
Varsayılanlar fal.ai gerektirmez: Gemini try-on + Gemini izolasyon + TRELLIS.2 3D. FASHN, BiRefNet, Hunyuan3D ve Tripo ücretli fal.ai bakiyesi ister.
Emülatörde `.env.local` → `MOCK_PROVIDERS=all` (maliyetsiz). Vertex, kıyafeti önce segmentasyon sağlayıcısıyla izole eder ve sonucu önbelleğe alır.
3D: `Model3DProvider.needsIsolatedInput=false` olan sağlayıcıda (TRELLIS, TRELLIS.2) pipeline segmentasyon adımını atlar.
Kaydetmeden önce `makeNonMetallic` tüm malzemelerde `metallicFactor=0` yazar: glTF'te alan yoksa 1 (tam metal) sayılır ve
metal yüzey kendi rengini göstermediği için kumaş koyu/kahverengi görünüyordu.

### TRELLIS.2 ayarları (`providers/model3d/hf_trellis2.ts`)
Sırasıyla `/start_session` → `/preprocess_image` → `/image_to_3d` → `/extract_glb`; ara durum Gradio oturumunda tutulduğu için
tek istemci bağlantısı kullanılır. Varsayılan: çözünürlük `1024`, 300 bin üçgen, 2048 px doku (GLB ≈ 10 MB, ≈ 60 sn).
Önizleme, demonun HTML'indeki ışıklandırılmış önden render'dan (`view-m3-s4`) kırpılır.
Uygulamadaki görüntüleyici `neutral` ortam ışığı, 1.2 pozlama ve `commerce` ton eşleme kullanır.

### TRELLIS kotası
Herkese açık Hugging Face demosu ekran kartını ZeroGPU kotasıyla paylaştırır. Anonim kota çok düşüktür (günde yaklaşık bir model).
TRELLIS.2 her modelde iki GPU çağrısı yapar (üretim + GLB çıkarma);
ücretsiz bir Hugging Face hesabının okuma anahtarı (`HF_TOKEN`) kotayı artırır. Kota dolunca iş `failed` olur, kredi iade edilir ve
kullanıcı "Ücretsiz 3D kotası doldu" mesajını görür. Demo kapanabilir veya API'si değişebilir; canlı kullanımda fal.ai (`MODEL3D_PROVIDER=hunyuan`)
ya da ücretli bir Hugging Face planı düşünülmelidir.

## Gizli anahtarlar ve parametreler
```
firebase functions:secrets:set GEMINI_API_KEY
firebase functions:secrets:set HF_TOKEN   # yoksa değer olarak unset girin
firebase functions:secrets:set FAL_KEY    # fal.ai kullanılmıyorsa değer olarak unset girin
```
`unset` değeri boş anahtar sayılır. Üç gizli anahtar da fonksiyonlara bağlı olduğu için deploy öncesi üçü de tanımlı olmalıdır.
Emülatör için `functions/.secret.local` (örnek: `.secret.local.example`). Vertex, fonksiyonun servis hesabıyla (ADC) çalışır;
projede **Vertex AI API** açık olmalı ve servis hesabına `roles/aiplatform.user` verilmeli.

## Tahmini maliyet (Eylül 2026 liste fiyatları)
| İşlem | Sağlayıcı maliyeti | Kredi |
|---|---|---|
| Try-on (FASHN) | ~0,075 $ | 1 |
| Try-on (Vertex) | ~0,06 $ + BiRefNet ~0,01 $ | 1 |
| Yan + arka görünüm (Gemini image ×2) | ~0,08 $ | +1 |
| 3D model (Hunyuan3D dokulu) | ~0,48 $ + BiRefNet | 5 |
| Stüdyo avatar (Gemini image ×1-2 + QC) | ~0,04-0,09 $ | 1 |
| Foto QC / kıyafet analizi / stil (Gemini flash) | < 0,005 $ | ücretsiz, günlük sınırlı |

Maliyet kontrolü: `config/pricing.dailyCaps`, `config/flags` acil durdurma, `maxInstances: 10`, görseller ≤1536 px.

## Karşılaştırma (benchmark)
- Script: `npm run benchmark -- --pairs benchmark/pairs.json` (örnek: `benchmark/pairs.example.json`) → `benchmark/out/<koşu>/index.html`.
  Kuru çalışma: `npm run benchmark -- --mock --samples`. Gerçek: `FAL_KEY=... VERTEX_PROJECT_ID=kabin-app-2026` + `gcloud auth application-default login`.
- Uygulama içi: yönetici hesabı Profil → "Sağlayıcı karşılaştırması"; Dene ekranında sağlayıcı seçimi.
  Yönetici yapmak: `npm run grant -- --uid <uid> --admin` (prod için `GOOGLE_APPLICATION_CREDENTIALS`).

## Testler
- `npm test` → saf testler (emülatörsüz testler atlanır).
- `npm run test:emu` → Firestore/Storage/Auth emülatöründe kredi, iş, iade, süpürücü, 3D, avatar, benchmark, hesap silme ve güvenlik kuralları.
