import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../notifiers/auth/auth_notifier.dart';
import '../../repositories/auth/auth_repository.dart';
import '../../services/firebase/auth_service.dart';
import '../core/core_providers.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(authServiceProvider), ref.watch(functionsServiceProvider));
});

/// Firebase Auth oturum akışı. Ekranlar bunu doğrudan izlemez; [appSessionProvider] kullanılır.
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateChangesProvider).value?.uid;
});

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// Yönetici yetkisi (custom claim). Benchmark ekranı ve sağlayıcı seçimi için.
final isAdminProvider = FutureProvider<bool>((ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return false;
  try {
    return await ref.watch(authRepositoryProvider).isAdmin(refresh: true);
  } catch (_) {
    return false;
  }
});
