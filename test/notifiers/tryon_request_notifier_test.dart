import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabin/core/enums/enums.dart';
import 'package:kabin/core/errors/errors.dart';
import 'package:kabin/models/models.dart';
import 'package:kabin/notifiers/tryon/tryon_request_notifier.dart';
import 'package:kabin/providers/auth/auth_providers.dart';
import 'package:kabin/providers/core/core_providers.dart';
import 'package:kabin/providers/tryon/tryon_providers.dart';
import 'package:mocktail/mocktail.dart';

import 'mocks.dart';

void main() {
  const photo = PhotoModel(id: 'p1', status: PhotoStatus.ready, storagePath: 'users/u1/photos/p1/original.jpg');
  const garment = GarmentModel(
    id: 'g1',
    status: GarmentStatus.ready,
    storagePath: 'users/u1/garments/g1/original.jpg',
    analysis: GarmentAnalysisModel(category: GarmentCategory.tops, titleTr: 'Tişört'),
  );
  const shoes = GarmentModel(
    id: 'g2',
    status: GarmentStatus.ready,
    storagePath: 'x',
    analysis: GarmentAnalysisModel(category: GarmentCategory.shoes),
  );

  late MockTryOnRepository repo;
  late ProviderContainer container;
  late ValueNotifier<String?> uid;

  setUp(() {
    repo = MockTryOnRepository();
    uid = ValueNotifier<String?>('u1');
    container = ProviderContainer(
      overrides: [
        currentUidProvider.overrideWith((ref) {
          void listener() => ref.invalidateSelf();
          uid.addListener(listener);
          ref.onDispose(() => uid.removeListener(listener));
          return uid.value;
        }),
        tryOnRepositoryProvider.overrideWithValue(repo),
        analyticsServiceProvider.overrideWithValue(MockAnalytics()),
        crashlyticsServiceProvider.overrideWithValue(MockCrashlytics()),
      ],
    );
    addTearDown(container.dispose);
  });

  TryOnRequestNotifierAccess n() => TryOnRequestNotifierAccess(container);

  test('seçim olmadan gönderilemez', () async {
    expect(container.read(tryOnRequestNotifierProvider).canSubmit, isFalse);
    expect(await n().notifier.submit(), isNull);
    expect(n().state.error, contains('fotoğraf'));
    verifyNever(
      () => repo.requestTryOn(
        photoId: any(named: 'photoId'),
        garmentId: any(named: 'garmentId'),
        multiView: any(named: 'multiView'),
      ),
    );
  });

  test('desteklenmeyen kıyafet reddedilir', () async {
    n().notifier
      ..selectPhoto(photo)
      ..selectGarment(shoes);
    expect(n().state.canSubmit, isFalse);
    expect(await n().notifier.submit(), isNull);
    expect(n().state.error, contains('denenemiyor'));
  });

  test('başarılı istek iş kimliğini döner', () async {
    when(() => repo.requestTryOn(photoId: 'p1', garmentId: 'g1', multiView: true, provider: null))
        .thenAnswer((_) async => const TryOnRequestResult(jobId: 'job-1', cost: 2, creditsLeft: 8));
    n().notifier
      ..selectPhoto(photo)
      ..selectGarment(garment);
    expect(n().state.canSubmit, isTrue);
    final jobId = await n().notifier.submit();
    expect(jobId, 'job-1');
    expect(n().state.createdJobId, 'job-1');
    expect(n().state.isSubmitting, isFalse);
  });

  test('yetersiz kredi bayrağı kredi ekranına yönlendirmeyi tetikler', () async {
    when(() => repo.requestTryOn(photoId: 'p1', garmentId: 'g1', multiView: false, provider: null))
        .thenThrow(const InsufficientCreditsException('Bu işlem için 1 kredi gerekiyor, bakiyeniz 0.', required: 1, available: 0));
    n().notifier
      ..selectPhoto(photo)
      ..selectGarment(garment)
      ..setMultiView(false);
    expect(await n().notifier.submit(), isNull);
    expect(n().state.needsCredits, isTrue);
    expect(n().state.error, contains('kredi'));
    n().notifier.clearError();
    expect(n().state.needsCredits, isFalse);
  });

  test('oturum değişince seçim sıfırlanır (hesaplar arası sızıntı yok)', () {
    container.listen(tryOnRequestNotifierProvider, (_, _) {});
    n().notifier
      ..selectPhoto(photo)
      ..selectGarment(garment);
    expect(n().state.photo, photo);
    uid.value = 'u2';
    expect(n().state.photo, isNull);
    expect(n().state.garment, isNull);
  });

  test('silinen kıyafet seçimden düşer', () {
    n().notifier
      ..selectPhoto(photo)
      ..selectGarment(garment)
      ..forgetGarment('g1');
    expect(n().state.garment, isNull);
    expect(n().state.photo, photo);
  });
}

class TryOnRequestNotifierAccess {
  TryOnRequestNotifierAccess(this.c);
  final ProviderContainer c;
  TryOnRequestNotifier get notifier => c.read(tryOnRequestNotifierProvider.notifier);
  TryOnRequestState get state => c.read(tryOnRequestNotifierProvider);
}
