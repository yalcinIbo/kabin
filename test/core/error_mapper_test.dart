import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabin/core/errors/errors.dart';

void main() {
  group('ErrorMapper.mapFunctions', () {
    test('yetersiz kredi → InsufficientCreditsException', () {
      final e = ErrorMapper.mapFunctions('resource-exhausted', 'Bu işlem için 2 kredi gerekiyor, bakiyeniz 1.', {
        'reason': 'insufficient-credits',
        'required': 2,
        'available': 1,
      });
      expect(e, isA<InsufficientCreditsException>());
      expect((e as InsufficientCreditsException).required, 2);
      expect(e.message, contains('2 kredi'));
    });

    test('büyük harfli platform kodu ve günlük sınır → RateLimitException', () {
      final e = ErrorMapper.mapFunctions('RESOURCE_EXHAUSTED', 'Bugünkü sınır doldu.', {'reason': 'daily-cap'});
      expect(e, isA<RateLimitException>());
      expect(e.message, 'Bugünkü sınır doldu.');
    });

    test('yeniden giriş gereksinimi → AuthException', () {
      final e = ErrorMapper.mapFunctions('failed-precondition', 'Yeniden giriş yap.', {'reason': 'requires-recent-login'});
      expect(e, isA<AuthException>());
      expect(e.code, 'requires-recent-login');
    });

    test('servis kapalı / yapılandırılmamış', () {
      expect(ErrorMapper.mapFunctions('unavailable', null, null), isA<ServiceUnavailableException>());
      expect(
        ErrorMapper.mapFunctions('failed-precondition', 'x', {'reason': 'provider-not-configured'}),
        isA<ServiceUnavailableException>(),
      );
    });

    test('geçersiz istek sunucu mesajını korur', () {
      final e = ErrorMapper.mapFunctions('failed-precondition', 'Seçilen kıyafet hazır değil.', {'reason': 'garment-not-ready'});
      expect(e, isA<ValidationException>());
      expect(e.message, 'Seçilen kıyafet hazır değil.');
      expect(e.code, 'garment-not-ready');
    });
  });

  test('FirebaseFunctionsException map() üzerinden eşlenir', () {
    final ex = FirebaseFunctionsException(message: 'Oturum yok', code: 'unauthenticated');
    expect(ErrorMapper.map(ex), isA<AuthException>());
  });
}
