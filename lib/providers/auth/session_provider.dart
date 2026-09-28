import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../models/user/user_model.dart';
import '../user/user_providers.dart';
import 'auth_providers.dart';

enum SessionStatus {
  /// Auth veya profil henüz yüklenmedi.
  loading,
  unauthenticated,

  /// Auth var; profil yok veya KVKK onayı güncel değil.
  needsOnboarding,
  authenticated,
}

class AppSession {
  const AppSession({required this.status, this.uid, this.user});

  final SessionStatus status;
  final String? uid;
  final UserModel? user;

  static const loading = AppSession(status: SessionStatus.loading);
  static const unauthenticated = AppSession(status: SessionStatus.unauthenticated);

  @override
  bool operator ==(Object other) => other is AppSession && other.status == status && other.uid == uid;

  @override
  int get hashCode => Object.hash(status, uid);
}

/// Router'ın izlediği tek oturum kaynağı.
final appSessionProvider = Provider<AppSession>((ref) {
  final auth = ref.watch(authStateChangesProvider);
  return auth.when(
    loading: () => AppSession.loading,
    error: (_, _) => AppSession.unauthenticated,
    data: (firebaseUser) {
      if (firebaseUser == null) return AppSession.unauthenticated;
      final profile = ref.watch(currentUserProvider);
      return profile.when(
        loading: () => AppSession(status: SessionStatus.loading, uid: firebaseUser.uid),
        error: (_, _) => AppSession(status: SessionStatus.needsOnboarding, uid: firebaseUser.uid),
        data: (user) {
          final consentOk = user?.consent?.isValidFor(AppConstants.kvkkVersion) ?? false;
          if (user == null || !consentOk) {
            return AppSession(status: SessionStatus.needsOnboarding, uid: firebaseUser.uid, user: user);
          }
          return AppSession(status: SessionStatus.authenticated, uid: user.id, user: user);
        },
      );
    },
  );
});
