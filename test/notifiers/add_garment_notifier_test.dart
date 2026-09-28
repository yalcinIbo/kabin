import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabin/core/enums/enums.dart';
import 'package:kabin/core/errors/errors.dart';
import 'package:kabin/models/models.dart';
import 'package:kabin/notifiers/garment/add_garment_notifier.dart';
import 'package:kabin/providers/auth/auth_providers.dart';
import 'package:kabin/providers/core/core_providers.dart';
import 'package:kabin/providers/garment/garment_providers.dart';
import 'package:kabin/repositories/garment/garment_repository.dart';
import 'package:kabin/services/media/image_service.dart';
import 'package:mocktail/mocktail.dart';

import 'mocks.dart';

void main() {
  final file = File('kiyafet.jpg');
  const analysis = GarmentAnalysisModel(category: GarmentCategory.tops, titleTr: 'Mavi tişört', colorNameTr: 'mavi');

  late MockGarmentRepository repo;
  late MockImageService images;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(File('x'));
    registerFallbackValue(analysis);
  });

  setUp(() {
    repo = MockGarmentRepository();
    images = MockImageService();
    when(() => images.pick(PickSource.gallery)).thenAnswer((_) async => file);
    when(() => repo.uploadGarment('u1', any(), onProgress: any(named: 'onProgress'))).thenAnswer((inv) async {
      (inv.namedArguments[#onProgress] as void Function(double)?)?.call(1);
      return 'g1';
    });
    container = ProviderContainer(
      overrides: [
        currentUidProvider.overrideWithValue('u1'),
        garmentRepositoryProvider.overrideWithValue(repo),
        imageServiceProvider.overrideWithValue(images),
        analyticsServiceProvider.overrideWithValue(MockAnalytics()),
        crashlyticsServiceProvider.overrideWithValue(MockCrashlytics()),
      ],
    );
    addTearDown(container.dispose);
    // autoDispose provider'ı test boyunca canlı tut.
    container.listen(addGarmentNotifierProvider, (_, _) {});
  });

  AddGarmentNotifier notifier() => container.read(addGarmentNotifierProvider.notifier);
  AddGarmentState state() => container.read(addGarmentNotifierProvider);

  test('seç → yükle → analiz → inceleme', () async {
    when(() => repo.analyzeGarment('g1'))
        .thenAnswer((_) async => const GarmentAnalysisResult(ready: true, analysis: analysis, tryonSupported: true));
    await notifier().pick(PickSource.gallery);
    expect(state().file, file);
    await notifier().submit();
    expect(state().step, AddGarmentStep.review);
    expect(state().garmentId, 'g1');
    expect(state().analysis?.titleTr, 'Mavi tişört');
    expect(state().analysisFailed, isFalse);
    expect(state().progress, 1);
  });

  test('değişiklik yoksa kaydetme sunucuya yazmaz; varsa yazar', () async {
    when(() => repo.analyzeGarment('g1'))
        .thenAnswer((_) async => const GarmentAnalysisResult(ready: true, analysis: analysis, tryonSupported: true));
    when(() => repo.updateAnalysis('u1', 'g1', any())).thenAnswer((_) async {});
    await notifier().pick(PickSource.gallery);
    await notifier().submit();
    expect(await notifier().save(), isTrue);
    verifyNever(() => repo.updateAnalysis(any(), any(), any()));

    notifier().updateAnalysis(analysis.copyWith(category: GarmentCategory.dresses));
    expect(await notifier().save(), isTrue);
    final captured = verify(() => repo.updateAnalysis('u1', 'g1', captureAny())).captured.single as GarmentAnalysisModel;
    expect(captured.category, GarmentCategory.dresses);
    expect(state().saved, isTrue);
  });

  test('kıyafet algılanamazsa uyarı; analiz hatasında tekrar denenebilir', () async {
    when(() => repo.analyzeGarment('g1'))
        .thenAnswer((_) async => const GarmentAnalysisResult(ready: false, analysis: analysis, tryonSupported: false));
    await notifier().pick(PickSource.gallery);
    await notifier().submit();
    expect(state().analysisFailed, isTrue);
    expect(state().error, contains('algılanamadı'));

    when(() => repo.analyzeGarment('g1')).thenThrow(const ServiceUnavailableException());
    await notifier().retryAnalyze();
    expect(state().step, AddGarmentStep.review);
    expect(state().error, contains('kullanılamıyor'));
  });
}
