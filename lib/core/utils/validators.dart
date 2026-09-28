import '../constants/app_constants.dart';

/// Form doğrulayıcıları. Null dönerse geçerlidir, aksi halde hata mesajı döner.
abstract final class Validators {
  static final RegExp _email = RegExp(r'^[\w\.\-+]+@([\w\-]+\.)+[a-zA-Z]{2,}$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'E-posta gerekli.';
    if (!_email.hasMatch(v)) return 'Geçerli bir e-posta girin.';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Şifre gerekli.';
    if (v.length < 8) return 'Şifre en az 8 karakter olmalı.';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) return 'Şifre harf ve rakam içermeli.';
    return null;
  }

  static String? confirmPassword(String? value, String original) => value != original ? 'Şifreler eşleşmiyor.' : null;

  static String? displayName(String? value) {
    final v = value?.trim() ?? '';
    if (v.length > 60) return 'Ad en fazla 60 karakter olabilir.';
    return null;
  }

  static String? garmentTitle(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Başlık gerekli.';
    if (v.length > 60) return 'Başlık en fazla 60 karakter olabilir.';
    return null;
  }

  static String? heightCm(int? value) {
    if (value == null) return null;
    if (value < AppConstants.minHeightCm || value > AppConstants.maxHeightCm) {
      return 'Boy ${AppConstants.minHeightCm}-${AppConstants.maxHeightCm} cm arasında olmalı.';
    }
    return null;
  }

  static String? weightKg(int? value) {
    if (value == null) return null;
    if (value < AppConstants.minWeightKg || value > AppConstants.maxWeightKg) {
      return 'Kilo ${AppConstants.minWeightKg}-${AppConstants.maxWeightKg} kg arasında olmalı.';
    }
    return null;
  }
}
