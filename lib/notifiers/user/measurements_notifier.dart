import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/errors.dart';
import '../../models/user/user_model.dart';
import '../../providers/auth/auth_providers.dart';
import '../../providers/user/user_providers.dart';

class MeasurementsState {
  const MeasurementsState({
    this.measurements = const Measurements(),
    this.displayName = '',
    this.isSaving = false,
    this.error,
    this.saved = false,
  });

  final Measurements measurements;
  final String displayName;
  final bool isSaving;
  final String? error;
  final bool saved;

  MeasurementsState copyWith({
    Measurements? measurements,
    String? displayName,
    bool? isSaving,
    String? error,
    bool clearError = false,
    bool? saved,
  }) => MeasurementsState(
    measurements: measurements ?? this.measurements,
    displayName: displayName ?? this.displayName,
    isSaving: isSaving ?? this.isSaving,
    error: clearError ? null : (error ?? this.error),
    saved: saved ?? this.saved,
  );
}

/// Profil ekranında ölçüleri ve adı düzenleme.
class MeasurementsNotifier extends Notifier<MeasurementsState> {
  @override
  MeasurementsState build() {
    final user = ref.read(currentUserProvider).value;
    return MeasurementsState(measurements: user?.measurements ?? const Measurements(), displayName: user?.displayName ?? '');
  }

  void setMeasurements(Measurements value) => state = state.copyWith(measurements: value, saved: false, clearError: true);
  void setDisplayName(String value) => state = state.copyWith(displayName: value, saved: false);

  Future<bool> save() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return false;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await ref.read(userRepositoryProvider).updateMeasurements(uid, state.measurements, displayName: state.displayName);
      if (ref.mounted) state = state.copyWith(isSaving: false, saved: true);
      return true;
    } catch (e) {
      if (ref.mounted) state = state.copyWith(isSaving: false, error: ErrorMapper.map(e).message);
      return false;
    }
  }
}
