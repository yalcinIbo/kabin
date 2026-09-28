import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/errors.dart';
import '../../models/user/user_model.dart';
import '../../providers/auth/auth_providers.dart';
import '../../providers/core/core_providers.dart';
import '../../providers/user/user_providers.dart';

class OnboardingState {
  const OnboardingState({
    this.kvkkAccepted = false,
    this.aiTransferAccepted = false,
    this.displayName = '',
    this.measurements = const Measurements(),
    this.isSaving = false,
    this.error,
  });

  final bool kvkkAccepted;
  final bool aiTransferAccepted;
  final String displayName;
  final Measurements measurements;
  final bool isSaving;
  final String? error;

  bool get canContinue => kvkkAccepted && aiTransferAccepted;

  OnboardingState copyWith({
    bool? kvkkAccepted,
    bool? aiTransferAccepted,
    String? displayName,
    Measurements? measurements,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) => OnboardingState(
    kvkkAccepted: kvkkAccepted ?? this.kvkkAccepted,
    aiTransferAccepted: aiTransferAccepted ?? this.aiTransferAccepted,
    displayName: displayName ?? this.displayName,
    measurements: measurements ?? this.measurements,
    isSaving: isSaving ?? this.isSaving,
    error: clearError ? null : (error ?? this.error),
  );
}

/// KVKK açık rızası + (isteğe bağlı) ölçüler → profil oluşturma veya rıza güncelleme.
class OnboardingNotifier extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    final existing = ref.read(currentUserProvider).value;
    return OnboardingState(
      displayName: existing?.displayName ?? ref.read(authRepositoryProvider).currentDisplayName ?? '',
      measurements: existing?.measurements ?? const Measurements(),
    );
  }

  void setKvkk(bool value) => state = state.copyWith(kvkkAccepted: value, clearError: true);
  void setAiTransfer(bool value) => state = state.copyWith(aiTransferAccepted: value, clearError: true);
  void setDisplayName(String value) => state = state.copyWith(displayName: value);
  void setMeasurements(Measurements value) => state = state.copyWith(measurements: value, clearError: true);

  /// Profili oluşturur (veya mevcut profilin rızasını günceller). Başarılıysa true.
  Future<bool> complete({bool skipMeasurements = false}) async {
    if (!state.canContinue) {
      state = state.copyWith(error: 'Devam etmek için iki onayı da vermelisin.');
      return false;
    }
    final auth = ref.read(authRepositoryProvider);
    final uid = auth.currentUid;
    if (uid == null) {
      state = state.copyWith(error: 'Oturum bulunamadı.');
      return false;
    }
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final users = ref.read(userRepositoryProvider);
      final consent = ConsentModel(
        kvkkVersion: AppConstants.kvkkVersion,
        kvkkAccepted: true,
        aiTransferAccepted: true,
        acceptedAt: DateTime.now(),
      );
      final measurements = skipMeasurements ? const Measurements() : state.measurements;
      final existing = await users.getUser(uid);
      if (existing == null) {
        await users.createProfile(
          uid: uid,
          displayName: state.displayName,
          email: auth.currentEmail,
          consent: consent,
          measurements: measurements,
        );
      } else {
        await users.updateConsent(uid, consent);
        if (!skipMeasurements) await users.updateMeasurements(uid, measurements, displayName: state.displayName);
      }
      ref.read(analyticsServiceProvider).logEvent('onboarding_completed', {'measurements': skipMeasurements ? 0 : 1});
      if (ref.mounted) state = state.copyWith(isSaving: false);
      return true;
    } catch (e, st) {
      if (e is! AppException) ref.read(crashlyticsServiceProvider).recordError(e, st);
      if (ref.mounted) state = state.copyWith(isSaving: false, error: ErrorMapper.map(e).message);
      return false;
    }
  }
}
