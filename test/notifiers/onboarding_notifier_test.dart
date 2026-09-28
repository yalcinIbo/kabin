import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabin/core/constants/app_constants.dart';
import 'package:kabin/core/enums/enums.dart';
import 'package:kabin/models/models.dart';
import 'package:kabin/providers/auth/auth_providers.dart';
import 'package:kabin/providers/core/core_providers.dart';
import 'package:kabin/providers/user/user_providers.dart';
import 'package:mocktail/mocktail.dart';

import 'mocks.dart';

void main() {
  late MockUserRepository users;
  late MockAuthRepository auth;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(const ConsentModel(kvkkVersion: '', kvkkAccepted: false, aiTransferAccepted: false));
    registerFallbackValue(const Measurements());
  });

  setUp(() {
    users = MockUserRepository();
    auth = MockAuthRepository();
    when(() => auth.currentUid).thenReturn('u1');
    when(() => auth.currentEmail).thenReturn('ayse@example.com');
    when(() => auth.currentDisplayName).thenReturn('Ayşe');
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(users),
        currentUserProvider.overrideWith((ref) => Stream.value(null)),
        analyticsServiceProvider.overrideWithValue(MockAnalytics()),
        crashlyticsServiceProvider.overrideWithValue(MockCrashlytics()),
      ],
    );
    addTearDown(container.dispose);
    container.listen(onboardingNotifierProvider, (_, _) {});
  });

  test('iki onay olmadan tamamlanamaz', () async {
    final n = container.read(onboardingNotifierProvider.notifier);
    n.setKvkk(true);
    expect(await n.complete(), isFalse);
    expect(container.read(onboardingNotifierProvider).error, contains('iki onayı'));
    verifyNever(
      () => users.createProfile(
        uid: any(named: 'uid'),
        displayName: any(named: 'displayName'),
        email: any(named: 'email'),
        consent: any(named: 'consent'),
        measurements: any(named: 'measurements'),
      ),
    );
  });

  test('yeni kullanıcı için güncel KVKK sürümüyle profil oluşturur', () async {
    when(() => users.getUser('u1')).thenAnswer((_) async => null);
    when(
      () => users.createProfile(
        uid: any(named: 'uid'),
        displayName: any(named: 'displayName'),
        email: any(named: 'email'),
        consent: any(named: 'consent'),
        measurements: any(named: 'measurements'),
      ),
    ).thenAnswer((_) async {});
    final n = container.read(onboardingNotifierProvider.notifier);
    expect(container.read(onboardingNotifierProvider).displayName, 'Ayşe');
    n
      ..setKvkk(true)
      ..setAiTransfer(true)
      ..setMeasurements(const Measurements(heightCm: 168, weightKg: 58, bodyType: BodyType.slim));
    expect(await n.complete(), isTrue);
    final captured = verify(
      () => users.createProfile(
        uid: 'u1',
        displayName: 'Ayşe',
        email: 'ayse@example.com',
        consent: captureAny(named: 'consent'),
        measurements: captureAny(named: 'measurements'),
      ),
    ).captured;
    final consent = captured[0] as ConsentModel;
    final measurements = captured[1] as Measurements;
    expect(consent.isValidFor(AppConstants.kvkkVersion), isTrue);
    expect(measurements.heightCm, 168);
  });

  test('mevcut profilde yalnızca rıza güncellenir (ölçüler atlandıysa)', () async {
    when(() => users.getUser('u1')).thenAnswer((_) async => const UserModel(id: 'u1', credits: 3));
    when(() => users.updateConsent('u1', any())).thenAnswer((_) async {});
    final n = container.read(onboardingNotifierProvider.notifier)
      ..setKvkk(true)
      ..setAiTransfer(true);
    expect(await n.complete(skipMeasurements: true), isTrue);
    verify(() => users.updateConsent('u1', any())).called(1);
    verifyNever(() => users.updateMeasurements(any(), any(), displayName: any(named: 'displayName')));
  });
}
