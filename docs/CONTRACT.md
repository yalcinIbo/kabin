# Kabin — Mimari sözleşme

## Katmanlar
```
Screen (ConsumerWidget) → Notifier (Riverpod 3) → Repository → Service → Firebase / Cloud Functions
```
- **Screens** (`lib/screens/**`): yalnızca provider/notifier kullanır. Yan etkiler (snackbar, navigasyon) `ref.listen` ile.
- **Notifiers** (`lib/notifiers/**`): immutable state + `copyWith`; `AppException` yakalayıp `state.error` (Türkçe) yazar.
  Async boşluklardan sonra `ref.mounted` kontrol edilir. Aile argümanı constructor'dan gelir.
- **Repositories** (`lib/repositories/**`): Firestore/Storage/Functions işlemleri; `AppException` fırlatır.
- **Services** (`lib/services/**`): Firebase ve eklenti örneklerinin tek sahibi. `FunctionsService` callable hatalarını `ErrorMapper` ile eşler.
- **Providers** (`lib/providers/<domain>/`): servis → repository → notifier bağlantıları. Adlandırma: `xServiceProvider`, `xRepositoryProvider`, `xNotifierProvider`, `xProvider`.

## Provider türleri
| Tür | Kullanım |
|---|---|
| `Provider` | Servis ve repository enjeksiyonu, türetilmiş değerler (`appSessionProvider`, `creditsProvider`) |
| `StreamProvider(.autoDispose.family)` | Canlı belgeler: `currentUserProvider`, `tryOnJobProvider(id)`, `model3dProvider(id)`, `photoProvider(id)` |
| `NotifierProvider` | Akışlar: `authNotifierProvider`, `onboardingNotifierProvider`, `addPhotoNotifierProvider`, `addGarmentNotifierProvider`, `tryOnRequestNotifierProvider`… |
| `AsyncNotifierProvider` + `PagedNotifier<T>` | Sayfalı listeler: fotoğraflar, kıyafetler, geçmiş, kredi hareketleri |
| `FutureProvider.family` | `storageUrlProvider(path)` (URL önbelleği), `localGlbProvider(modelId)` |

## Hata sözleşmesi
Sunucu `HttpsError(code, mesajTr, {reason})` fırlatır. İstemci eşlemesi (`ErrorMapper.mapFunctions`):
| code / reason | İstemci tipi |
|---|---|
| `resource-exhausted` + `insufficient-credits` | `InsufficientCreditsException` → kredi ekranına yönlendirme |
| `resource-exhausted` + `daily-cap` | `RateLimitException` |
| `failed-precondition` + `requires-recent-login` | `AuthException` |
| `failed-precondition` + `provider-not-configured`, `unavailable` | `ServiceUnavailableException` |
| `invalid-argument`, `failed-precondition` | `ValidationException` (sunucu mesajı) |

## Oturum ve yönlendirme
`SessionStatus`: `loading → splash`, `unauthenticated → /login`, `needsOnboarding → /onboarding/consent`
(profil yok veya `consent.kvkkVersion != AppConstants.kvkkVersion`), `authenticated → /try`. Kural: `appRedirect()` (saf, test edilir).

## İş akışı (istemci tarafı)
1. `requestTryOn` callable → `{jobId, cost, creditsLeft}`.
2. `TryOnJobScreen` `tryOnJobProvider(jobId)` ile `status/stage/progress` izler.
3. `done` → sonuç karuseli (ön/yan/arka), stil kartı, paylaş, 3D. `failed` → `error.messageTr` + iade bilgisi.
