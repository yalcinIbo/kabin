import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/enums/enums.dart';
import '../../core/errors/errors.dart';

/// Firebase Authentication ile konuşan tek sınıf. Firestore'a dokunmaz.
class AuthService {
  AuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
    : _auth = auth ?? FirebaseAuth.instance,
      _google = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _google;
  bool _googleInitialized = false;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Profil/verify değişikliklerini de yayınlar.
  Stream<User?> userChanges() => _auth.userChanges();

  User? get currentUser => _auth.currentUser;
  String? get currentUid => _auth.currentUser?.uid;
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  AuthProviderType get currentProviderType {
    final providers = _auth.currentUser?.providerData.map((p) => p.providerId) ?? const [];
    if (providers.contains('google.com')) return AuthProviderType.google;
    if (providers.contains('apple.com')) return AuthProviderType.apple;
    return AuthProviderType.email;
  }

  Future<UserCredential> signInWithEmail(String email, String password) =>
      _guard(() => _auth.signInWithEmailAndPassword(email: email.trim(), password: password));

  Future<UserCredential> signUpWithEmail(String email, String password) =>
      _guard(() => _auth.createUserWithEmailAndPassword(email: email.trim(), password: password));

  Future<UserCredential> signInWithGoogle() => _guard(() async {
    final credential = await _googleCredential();
    return _auth.signInWithCredential(credential);
  });

  Future<UserCredential> signInWithApple() => _guard(() async {
    final credential = await _appleCredential();
    return _auth.signInWithCredential(credential);
  });

  Future<void> sendEmailVerification() => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException('Oturum bulunamadı.', code: 'no-user');
    if (!user.emailVerified) await user.sendEmailVerification();
  });

  /// Kullanıcıyı yeniden yükler ve doğrulama durumunu döner.
  Future<bool> reloadAndCheckVerified() => _guard(() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  });

  Future<void> sendPasswordReset(String email) => _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  Future<void> updatePassword(String newPassword) => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException('Oturum bulunamadı.', code: 'no-user');
    await user.updatePassword(newPassword);
  });

  Future<void> updateDisplayName(String name) => _guard(() => _auth.currentUser?.updateDisplayName(name) ?? Future.value());

  /// Kritik işlemler (şifre değiştirme, hesap silme) öncesi re-auth.
  Future<void> reauthenticateWithPassword(String password) => _guard(() async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AuthException('Oturum bulunamadı.', code: 'no-user');
    }
    final credential = EmailAuthProvider.credential(email: email, password: password);
    await user.reauthenticateWithCredential(credential);
  });

  Future<void> reauthenticateWithProvider(AuthProviderType provider) => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException('Oturum bulunamadı.', code: 'no-user');
    final credential = switch (provider) {
      AuthProviderType.google => await _googleCredential(),
      AuthProviderType.apple => await _appleCredential(),
      AuthProviderType.email => throw const AuthException('Şifre ile doğrulama gerekli.', code: 'password-required'),
    };
    await user.reauthenticateWithCredential(credential);
  });

  Future<void> signOut() => _guard(() async {
    await Future.wait([_auth.signOut(), _signOutGoogleSilently()]);
  });

  /// Yalnızca Auth hesabını siler. Firestore/Storage temizliği repository + backend işidir.
  Future<void> deleteCurrentUser() => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException('Oturum bulunamadı.', code: 'no-user');
    await user.delete();
    await _signOutGoogleSilently();
  });

  Future<String?> getIdToken({bool forceRefresh = false}) =>
      _guard(() => _auth.currentUser?.getIdToken(forceRefresh) ?? Future.value(null));

  /// Özel yetki (custom claim) `admin == true` mı? Token yenilenerek okunur.
  Future<bool> hasAdminClaim({bool forceRefresh = false}) => _guard(() async {
    final result = await _auth.currentUser?.getIdTokenResult(forceRefresh);
    return result?.claims?['admin'] == true;
  });

  // ---- providers ----

  Future<OAuthCredential> _googleCredential() async {
    if (!_googleInitialized) {
      await _google.initialize();
      _googleInitialized = true;
    }
    final GoogleSignInAccount account;
    try {
      account = await _google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthException('Giriş iptal edildi.', code: 'canceled');
      }
      throw AuthException('Google ile giriş başarısız: ${e.description ?? e.code.name}', code: e.code.name, cause: e);
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException('Google kimlik bilgisi alınamadı.', code: 'google-no-token');
    }
    return GoogleAuthProvider.credential(idToken: idToken);
  }

  Future<OAuthCredential> _appleCredential() async {
    final rawNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
    final AuthorizationCredentialAppleID apple;
    try {
      apple = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const AuthException('Giriş iptal edildi.', code: 'canceled');
      }
      throw AuthException('Apple ile giriş başarısız: ${e.message}', code: e.code.name, cause: e);
    }
    final idToken = apple.identityToken;
    if (idToken == null) {
      throw const AuthException('Apple kimlik bilgisi alınamadı.', code: 'apple-no-token');
    }
    return OAuthProvider('apple.com').credential(idToken: idToken, rawNonce: rawNonce, accessToken: apple.authorizationCode);
  }

  Future<void> _signOutGoogleSilently() async {
    try {
      if (_googleInitialized) await _google.signOut();
    } catch (_) {
      // Google oturumu kapanmasa bile Firebase oturumu kapanmıştır.
    }
  }

  static String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }
}
