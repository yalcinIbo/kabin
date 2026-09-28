import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/errors.dart';
import '../../providers/auth/auth_providers.dart';
import '../../providers/core/core_providers.dart';
import '../../repositories/auth/auth_repository.dart';

class AuthState {
  const AuthState({this.isLoading = false, this.error});

  final bool isLoading;
  final String? error;

  AuthState copyWith({bool? isLoading, String? error, bool clearError = false}) =>
      AuthState(isLoading: isLoading ?? this.isLoading, error: clearError ? null : (error ?? this.error));
}

/// Giriş, kayıt, çıkış ve hesap silme aksiyonları.
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<bool> signInWithEmail(String email, String password) => _run(() async {
    await _repo.signInWithEmail(email, password);
    ref.read(analyticsServiceProvider).logLogin('email');
  });

  Future<bool> signUpWithEmail(String email, String password) => _run(() async {
    await _repo.signUpWithEmail(email, password);
    ref.read(analyticsServiceProvider).logSignUp('email');
  });

  Future<bool> signInWithGoogle() => _run(() async {
    final isNew = await _repo.signInWithGoogle();
    final analytics = ref.read(analyticsServiceProvider);
    isNew ? analytics.logSignUp('google') : analytics.logLogin('google');
  });

  Future<bool> signInWithApple() => _run(() async {
    final isNew = await _repo.signInWithApple();
    final analytics = ref.read(analyticsServiceProvider);
    isNew ? analytics.logSignUp('apple') : analytics.logLogin('apple');
  });

  Future<bool> sendPasswordReset(String email) => _run(() => _repo.sendPasswordReset(email));

  Future<bool> signOut() => _run(_repo.signOut);

  /// Kalıcı hesap silme (KVKK): yeniden kimlik doğrulama + sunucuda tüm verilerin silinmesi.
  Future<bool> deleteAccount({String? password}) => _run(() => _repo.deleteAccount(password: password));

  void clearError() => state = state.copyWith(clearError: true);

  Future<bool> _run(Future<void> Function() action) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await action();
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e, st) {
      if (e is! AppException) ref.read(crashlyticsServiceProvider).recordError(e, st);
      state = state.copyWith(isLoading: false, error: ErrorMapper.map(e).message);
      return false;
    }
  }
}
