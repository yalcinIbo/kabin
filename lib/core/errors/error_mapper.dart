import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app_exception.dart';

/// Dış sistem hatalarını [AppException]'a çevirir.
/// Service ve Repository katmanları `catch (e) { throw ErrorMapper.map(e); }` kullanır.
abstract final class ErrorMapper {
  static AppException map(Object error) {
    if (error is AppException) return error;
    if (error is FirebaseFunctionsException) return mapFunctions(error.code, error.message, error.details);
    if (error is FirebaseAuthException) return _mapAuth(error);
    if (error is FirebaseException) return _mapFirebase(error);
    if (error is SocketException || error is TimeoutException) return const NetworkException();
    if (error is FormatException) return const ValidationException('Geçersiz veri formatı.', code: 'format');
    return UnknownException('Beklenmeyen bir hata oluştu.', error);
  }

  /// Callable hatalarını eşler. Sunucu Türkçe mesaj ve `details.reason` gönderir.
  static AppException mapFunctions(String rawCode, String? message, Object? details) {
    final code = rawCode.toLowerCase().replaceAll('_', '-');
    final info = details is Map ? details : const {};
    final reason = info['reason']?.toString();
    final serverMessage = (message != null && message.trim().isNotEmpty) ? message.trim() : null;
    switch (code) {
      case 'unauthenticated':
        return AuthException(serverMessage ?? 'Oturumun sona erdi. Lütfen tekrar giriş yap.', code: code);
      case 'permission-denied':
        return PermissionException(serverMessage ?? 'Bu işlem için yetkiniz yok.');
      case 'not-found':
        return NotFoundException(serverMessage ?? 'İçerik bulunamadı.');
      case 'resource-exhausted':
        if (reason == 'insufficient-credits') {
          return InsufficientCreditsException(
            serverMessage ?? 'Krediniz yetersiz.',
            required: _toInt(info['required']),
            available: _toInt(info['available']),
          );
        }
        return RateLimitException(serverMessage ?? 'Çok fazla istek gönderdiniz. Biraz bekleyin.');
      case 'invalid-argument':
      case 'failed-precondition':
        if (reason == 'requires-recent-login') {
          return AuthException(serverMessage ?? 'Güvenlik için lütfen yeniden giriş yap.', code: 'requires-recent-login');
        }
        if (reason == 'provider-not-configured') {
          return ServiceUnavailableException(serverMessage ?? 'Servis şu anda kullanılamıyor.');
        }
        return ValidationException(serverMessage ?? 'İstek geçersiz.', code: reason ?? code);
      case 'deadline-exceeded':
        return const NetworkException('İşlem zaman aşımına uğradı. Lütfen tekrar deneyin.');
      case 'unavailable':
        return ServiceUnavailableException(serverMessage ?? 'Servis şu anda kullanılamıyor. Lütfen daha sonra tekrar deneyin.');
      default:
        return UnknownException(serverMessage ?? 'Sunucu hatası oluştu.');
    }
  }

  static int? _toInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);

  static AuthException _mapAuth(FirebaseAuthException e) {
    final message = switch (e.code) {
      'invalid-email' => 'Geçersiz e-posta adresi.',
      'user-disabled' => 'Bu hesap devre dışı bırakılmış.',
      'user-not-found' => 'Bu e-posta ile kayıtlı kullanıcı bulunamadı.',
      'wrong-password' => 'Şifre hatalı.',
      'invalid-credential' => 'E-posta veya şifre hatalı.',
      'email-already-in-use' => 'Bu e-posta adresi zaten kullanımda.',
      'weak-password' => 'Şifre çok zayıf. En az 8 karakter kullanın.',
      'operation-not-allowed' => 'Bu giriş yöntemi etkin değil.',
      'too-many-requests' => 'Çok fazla deneme yapıldı. Lütfen daha sonra tekrar deneyin.',
      'requires-recent-login' => 'Güvenlik için lütfen yeniden giriş yapın.',
      'network-request-failed' => 'İnternet bağlantısı yok. Lütfen tekrar deneyin.',
      'account-exists-with-different-credential' => 'Bu e-posta başka bir giriş yöntemiyle kayıtlı.',
      'user-mismatch' => 'Kimlik bilgileri bu hesapla eşleşmiyor.',
      'popup-closed-by-user' || 'canceled' || 'sign_in_canceled' => 'Giriş iptal edildi.',
      _ => 'Kimlik doğrulama hatası: ${e.message ?? e.code}',
    };
    return AuthException(message, code: e.code, cause: e);
  }

  static AppException _mapFirebase(FirebaseException e) {
    return switch (e.code) {
      'permission-denied' || 'unauthorized' => const PermissionException(),
      'not-found' || 'object-not-found' => const NotFoundException(),
      'unavailable' || 'network-request-failed' => const NetworkException(),
      'resource-exhausted' => const RateLimitException(),
      'canceled' => StorageException('Yükleme iptal edildi.', code: e.code, cause: e),
      'quota-exceeded' => StorageException('Depolama kotası aşıldı.', code: e.code, cause: e),
      _ => UnknownException(e.message ?? 'Sunucu hatası oluştu.', e),
    };
  }
}
