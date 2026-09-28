import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabin/models/models.dart';
import 'package:kabin/providers/auth/auth_providers.dart';
import 'package:kabin/providers/core/core_providers.dart';
import 'package:kabin/providers/photo/photo_providers.dart';
import 'package:kabin/providers/tryon/tryon_providers.dart';
import 'package:kabin/repositories/photo/photo_repository.dart';
import 'package:kabin/services/media/image_service.dart';
import 'package:mocktail/mocktail.dart';

import 'mocks.dart';

void main() {
  final file = File('boydan.jpg');
  late MockPhotoRepository repo;
  late ProviderContainer container;

  setUpAll(() => registerFallbackValue(File('x')));

  setUp(() {
    repo = MockPhotoRepository();
    final images = MockImageService();
    when(() => images.pick(PickSource.gallery)).thenAnswer((_) async => file);
    when(() => repo.uploadPhoto('u1', any(), onProgress: any(named: 'onProgress'))).thenAnswer((_) async => 'p1');
    container = ProviderContainer(
      overrides: [
        currentUidProvider.overrideWithValue('u1'),
        photoRepositoryProvider.overrideWithValue(repo),
        imageServiceProvider.overrideWithValue(images),
        analyticsServiceProvider.overrideWithValue(MockAnalytics()),
        crashlyticsServiceProvider.overrideWithValue(MockCrashlytics()),
      ],
    );
    addTearDown(container.dispose);
    container.listen(addPhotoNotifierProvider, (_, _) {});
    container.listen(tryOnRequestNotifierProvider, (_, _) {});
  });

  Future<void> run() async {
    final notifier = container.read(addPhotoNotifierProvider.notifier);
    await notifier.pick(PickSource.gallery);
    await notifier.submit();
  }

  test('kontrolden geçen yeni fotoğraf Dene ekranında seçili olur', () async {
    when(() => repo.checkPhoto('p1'))
        .thenAnswer((_) async => const PhotoCheckResult(ready: true, qc: PhotoQcModel(passed: true, blocked: false), isDefault: false));
    when(() => repo.getPhoto('u1', 'p1')).thenAnswer((_) async => PhotoModel.fromMap({'status': 'ready'}, 'p1'));
    await run();
    expect(container.read(addPhotoNotifierProvider).passed, isTrue);
    expect(container.read(tryOnRequestNotifierProvider).photo?.id, 'p1');
  });

  test('reddedilen fotoğraf seçilmez', () async {
    when(() => repo.checkPhoto('p1'))
        .thenAnswer((_) async => const PhotoCheckResult(ready: false, qc: PhotoQcModel(passed: false, blocked: false), isDefault: false));
    await run();
    expect(container.read(tryOnRequestNotifierProvider).photo, isNull);
    verifyNever(() => repo.getPhoto(any(), any()));
  });
}
