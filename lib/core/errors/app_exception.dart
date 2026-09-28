/// Uygulama geneli hata sözleşmesi. Katmanlar dış hataları bu tiplere çevirir;
/// UI yalnızca [message] gösterir.
sealed class AppException implements Exception {
  const AppException(this.message, {this.code, this.cause});

  /// Kullanıcıya gösterilebilecek Türkçe mesaj.
  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => '$runtimeType(code: $code, message: $message)';
}

class AuthException extends AppException {
  const AuthException(super.message, {super.code, super.cause});
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'İnternet bağlantısı yok. Lütfen tekrar deneyin.']) : super(code: 'network');
}

class PermissionException extends AppException {
  const PermissionException([super.message = 'Bu işlem için yetkiniz yok.']) : super(code: 'permission-denied');
}

class NotFoundException extends AppException {
  const NotFoundException([super.message = 'İçerik bulunamadı.']) : super(code: 'not-found');
}

class ValidationException extends AppException {
  const ValidationException(super.message, {super.code});
}

class StorageException extends AppException {
  const StorageException(super.message, {super.code, super.cause});
}

class MediaException extends AppException {
  const MediaException(super.message, {super.code, super.cause});
}

class RateLimitException extends AppException {
  const RateLimitException([super.message = 'Çok fazla istek gönderdiniz. Biraz bekleyin.']) : super(code: 'rate-limit');
}

/// Kredi yetersiz; UI kredi ekranına yönlendirebilir.
class InsufficientCreditsException extends AppException {
  const InsufficientCreditsException(super.message, {this.required, this.available}) : super(code: 'insufficient-credits');
  final int? required;
  final int? available;
}

/// Sunucu tarafında iş (deneme/3D/avatar) başarısız oldu.
class JobFailedException extends AppException {
  const JobFailedException(super.message, {super.code});
}

/// Özellik geçici olarak kapalı veya servis yapılandırılmamış.
class ServiceUnavailableException extends AppException {
  const ServiceUnavailableException([super.message = 'Servis şu anda kullanılamıyor. Lütfen daha sonra tekrar deneyin.'])
    : super(code: 'unavailable');
}

class UnknownException extends AppException {
  const UnknownException([super.message = 'Beklenmeyen bir hata oluştu.', Object? cause]) : super(code: 'unknown', cause: cause);
}
