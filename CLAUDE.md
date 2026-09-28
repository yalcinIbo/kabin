# Kabin — proje kuralları

Sanal kıyafet deneme uygulaması: kullanıcının boydan fotoğrafı + kıyafet fotoğrafı → yapay zekâ ile giydirilmiş görsel,
yan/arka görünüm ve stil tavsiyesi. 3D model kodu duruyor ama `config/flags.model3dEnabled` ile kapalı (varsayılan false). Flutter 3.47 · Riverpod 3 · Firebase · Cloud Functions (Node 22, TS).
Teknik referans: `docs/CONTRACT.md` (mimari), `docs/FIRESTORE_SCHEMA.md` (veri + kurallar), `docs/BACKEND.md` (Functions, sağlayıcılar, maliyet).

## Değişmez kurallar
- Katman sırası: Screen → Notifier → Repository → Service → Firebase. Screen/Notifier içinde Firebase import'u yok.
- State yönetimi yalnızca Riverpod 3, elle yazılan provider'lar (`Notifier`/`AsyncNotifier`; `StateProvider`/`StateNotifier`/`ChangeNotifier` yok, code-gen yok).
- Klasör yapısı sabit: `lib/core, models, services, repositories, providers, notifiers, screens`.
- Listeler cursor tabanlı sayfalanır (`FirestoreService.getPage`, `PagedState`, `PagedNotifier`).
- Belgeler görsel **URL değil Storage yolu** saklar; ekranlar `StorageImage(path:)` kullanır.
- Kredi, iş durumu, sonuçlar yalnızca sunucuda yazılır. İstemci `credits` alanına asla yazmaz (kurallar da reddeder).
- Firestore/Storage yolları `FirestorePaths`/`StoragePaths` ile ve `functions/src/lib/paths.ts` ile birebir aynı tutulur.
- AI sağlayıcıları yalnızca `functions/src/providers/*` arayüzleri üzerinden çağrılır; yeni sağlayıcı = yeni sınıf + `factory.ts`.
- Her ücretli iş: callable transaction'da kredi düşer → tetikleyici `runJob` ile işler → hata/zaman aşımında `refundJob` (idempotent).
- UI metinleri Türkçe; renkler yalnızca `AppColors`/`Theme.of(context).colorScheme`. Tasarım dili: Fraunces serif başlık + Manrope metin (`AppType`), fildişi zemin, mürdüm kadife, kiremit vurgu; ortak parçalar `EditorialHeader`, `PaperCard`, `CurtainPainter`, `TabPage`.
- Kod biçimi: `dart format lib test` (satır genişliği 140, `analysis_options.yaml`).
- Her değişiklik sonrası: `flutter analyze` sıfır sorun, `flutter test` yeşil; backend için `npm run typecheck` ve `npm run test:emu` yeşil.

## Komutlar
- Flutter: `flutter analyze` · `flutter test` · `flutter run --dart-define=USE_EMULATORS=true`
- Backend (functions/): `npm run build` · `npm run typecheck` · `npm run test:emu` · `npm run seed` · `npm run benchmark -- --mock --samples`
- Emülatör (kök klasör): `firebase emulators:start --only auth,firestore,storage,functions` (Java gerekli)
