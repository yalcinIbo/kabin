import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user/user_model.dart';
import '../../notifiers/user/measurements_notifier.dart';
import '../../notifiers/user/onboarding_notifier.dart';
import '../../repositories/user/user_repository.dart';
import '../auth/auth_providers.dart';
import '../core/core_providers.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) => UserRepository(ref.watch(firestoreServiceProvider)));

/// Oturum açmış kullanıcının profili (canlı; kredi bakiyesi buradan okunur).
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watchUser(uid);
});

final creditsProvider = Provider<int>((ref) => ref.watch(currentUserProvider.select((u) => u.value?.credits ?? 0)));

final onboardingNotifierProvider = NotifierProvider.autoDispose<OnboardingNotifier, OnboardingState>(OnboardingNotifier.new);

final measurementsNotifierProvider = NotifierProvider.autoDispose<MeasurementsNotifier, MeasurementsState>(MeasurementsNotifier.new);
