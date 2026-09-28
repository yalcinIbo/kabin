import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/functions_names.dart';
import '../../core/enums/enums.dart';
import '../../core/errors/errors.dart';
import '../../services/firebase/auth_service.dart';
import '../../services/firebase/functions_service.dart';

/// Kimlik doğrulama ve hesap yaşam döngüsü.
class AuthRepository {
  AuthRepository(this._auth, this._functions);

  final AuthService _auth;
  final FunctionsService _functions;

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  String? get currentUid => _auth.currentUid;
  String? get currentEmail => _auth.currentUser?.email;
  String? get currentDisplayName => _auth.currentUser?.displayName;
  AuthProviderType get currentProvider => _auth.currentProviderType;

  Future<void> signInWithEmail(String email, String password) async {
    await _auth.signInWithEmail(email, password);
  }

  /// Kayıt: Auth hesabı oluşturur, doğrulama e-postası gönderir (başarısız olsa da kayıt tamamdır).
  Future<void> signUpWithEmail(String email, String password) async {
    await _auth.signUpWithEmail(email, password);
    try {
      await _auth.sendEmailVerification();
    } on AppException {
      // sonra tekrar denenebilir
    }
  }

  Future<bool> signInWithGoogle() async => (await _auth.signInWithGoogle()).additionalUserInfo?.isNewUser ?? false;
  Future<bool> signInWithApple() async => (await _auth.signInWithApple()).additionalUserInfo?.isNewUser ?? false;
  Future<void> sendPasswordReset(String email) => _auth.sendPasswordReset(email);
  Future<void> signOut() => _auth.signOut();

  Future<bool> isAdmin({bool refresh = false}) => _auth.hasAdminClaim(forceRefresh: refresh);

  Future<void> reauthenticate({String? password}) async {
    final provider = _auth.currentProviderType;
    if (provider == AuthProviderType.email) {
      if (password == null || password.isEmpty) {
        throw const ValidationException('Şifre gerekli.', code: 'password-required');
      }
      await _auth.reauthenticateWithPassword(password);
    } else {
      await _auth.reauthenticateWithProvider(provider);
    }
  }

  /// Kalıcı silme: yeniden kimlik doğrulama → sunucuda tüm veriler + Auth hesabı silinir → oturum kapanır.
  Future<void> deleteAccount({String? password}) async {
    await reauthenticate(password: password);
    await _auth.getIdToken(forceRefresh: true);
    await _functions.call(FunctionNames.deleteMyAccount, const {}, const Duration(minutes: 5));
    try {
      await _auth.signOut();
    } on AppException {
      // hesap silindiği için oturum zaten geçersiz
    }
  }
}
