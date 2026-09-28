# Kabin — sanal kıyafet deneme

"Bu kıyafet **üstümde** nasıl durur?" sorusunu satın almadan yanıtlayan mobil uygulama.
Kullanıcı boydan fotoğrafını (veya selfie + ölçülerden üretilen stüdyo fotoğrafını) ve denemek istediği kıyafetin
fotoğrafını seçer; yapay zekâ kıyafeti üzerine giydirir, yan/arka görünümleri ve Türkçe stil/beden önerisini üretir.
İstenirse sonuçtan döndürülebilir 3D model oluşturulur.

- **Flutter** 3.47 · Riverpod 3 · go_router · Firebase (Auth, Firestore, Storage, Functions, Crashlytics, Analytics)
- **Backend**: Cloud Functions (Node 22, TypeScript) — `functions/`
- **AI**: FASHN v1.6 (fal.ai) ve Google Vertex AI Virtual Try-On (karşılaştırmalı), Gemini (kalite kontrol, analiz,
  çoklu açı, stil), Hunyuan3D/Tripo (görüntüden 3D)
- Paket kimliği `com.kabinapp.kabin` · Firebase projesi `kabin-app-2026`

Ayrıntılar: [docs/CONTRACT.md](docs/CONTRACT.md) · [docs/FIRESTORE_SCHEMA.md](docs/FIRESTORE_SCHEMA.md) · [docs/BACKEND.md](docs/BACKEND.md)

## Yerelde çalıştırma (API anahtarı gerekmez)
Gereksinimler: Flutter 3.47+, Node 22+, Firebase CLI, Java 21 (`brew install openjdk@21`).

```bash
cd functions && npm install && npm run build && cd ..
export JAVA_HOME=/opt/homebrew/opt/openjdk@21
firebase emulators:start --only auth,firestore,storage,functions
```
Başka bir terminalde:
```bash
cd functions && npm run seed        # test@kabin.dev / Test1234! · 50 kredi · yönetici
cd .. && flutter run --dart-define=USE_EMULATORS=true
```
Emülatörde tüm AI servisleri **sahte** çalışır (`functions/.env.local` → `MOCK_PROVIDERS=all`); çıktılar "TEST" etiketlidir.
Gerçek Gemini'yi denemek için `functions/.secret.local` içine `GEMINI_API_KEY` yazıp örn. `MOCK_PROVIDERS=tryon,segmentation,imagegen,model3d` yapın.

## Canlıya alma kontrol listesi
1. Firebase konsolu → **Blaze** planına geç (Functions ve Storage için şart).
2. Firestore veritabanı ve Storage bucket'ı oluştur (bölge: `europe-west1`).
3. Authentication → E-posta/Şifre, Google ve Apple sağlayıcılarını aç.
   - Google: Android SHA-1/SHA-256 parmak izlerini ekle, sonra `flutterfire configure --project=kabin-app-2026` ile yapılandırmayı yenile;
     iOS için `GoogleService-Info.plist` içindeki `REVERSED_CLIENT_ID`'yi `Info.plist` URL şemalarına ekle.
   - Apple: Xcode'da "Sign in with Apple" yeteneğini aç, Apple Developer'da Service ID tanımla.
4. Anahtarlar: `GEMINI_API_KEY` zorunlu; `HF_TOKEN` (ücretsiz Hugging Face hesabı, 3D kotası için) ve `FAL_KEY` (yalnız FASHN/Hunyuan3D için) isteğe bağlı. Kullanılmayanlara değer olarak `unset` girin: `firebase functions:secrets:set HF_TOKEN`.
5. Vertex AI: GCP'de Vertex AI API'yi aç; Functions servis hesabına `roles/aiplatform.user` ver.
6. `functions/.env` içindeki `TRYON_PROVIDER`'ı benchmark sonucuna göre seç (`gemini` varsayılan | `fashn` | `vertex`); `MODEL3D_PROVIDER` varsayılanı ücretsiz `trellis2`.
7. Dağıt: `firebase deploy --only firestore:rules,firestore:indexes,storage,functions`.
8. `config/pricing` ve `config/flags` belgelerini oluştur (`functions/src/config/pricing.ts` varsayılanları) ve GCP bütçe uyarısı kur.
9. Storage yaşam döngüsü: `users/*/tmp/` 1 gün, `benchmarks/` 30 gün.
10. KVKK aydınlatma metnini (`lib/screens/settings/legal_screen.dart`) hukuk danışmanıyla kesinleştir; `AppConstants.kvkkVersion`'ı güncelle.

## Testler
```bash
flutter analyze && flutter test
cd functions && npm run typecheck && npm run test:emu
```

## Bilinen sınırlar ve riskler
- Sonuçlar yapay zekâ üretimidir; gerçek kesim/beden birebir yansımayabilir (uygulama içinde belirtilir).
- `flutter_3d_controller` (model-viewer WebView) ~1 yıldır güncellenmedi ve bağımlılığı `flutter_inappwebview_ios` Swift Package Manager desteklemiyor.
  3D görüntüleyici tek widget'ta izole; gerekirse doğrudan `flutter_inappwebview` + `<model-viewer>` ile değiştirilebilir.
- Vertex `virtual-try-on-001` Mart 2027'de emekliye ayrılacak; `VERTEX_TRYON_MODEL` parametresiyle yeni modele geçilir.
- Kredi satın alma (IAP) henüz yok; defter (`ledger`) `purchase_{txnId}` kayıtlarına hazır.
