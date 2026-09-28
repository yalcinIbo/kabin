import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/errors.dart';
import '../../providers/core/core_providers.dart';
import '../../providers/model3d/model3d_providers.dart';

class Model3DRequestState {
  const Model3DRequestState({this.isSubmitting = false, this.modelId, this.error, this.needsCredits = false});

  final bool isSubmitting;
  final String? modelId;
  final String? error;
  final bool needsCredits;

  Model3DRequestState copyWith({bool? isSubmitting, String? modelId, String? error, bool clearError = false, bool? needsCredits}) =>
      Model3DRequestState(
        isSubmitting: isSubmitting ?? this.isSubmitting,
        modelId: modelId ?? this.modelId,
        error: clearError ? null : (error ?? this.error),
        needsCredits: needsCredits ?? this.needsCredits,
      );
}

/// Bir denemeden 3D model üretimi isteği (aile argümanı: tryonId).
class Model3DRequestNotifier extends Notifier<Model3DRequestState> {
  Model3DRequestNotifier(this.tryonId);

  final String tryonId;

  @override
  Model3DRequestState build() => const Model3DRequestState();

  Future<String?> request() async {
    if (state.isSubmitting) return null;
    state = state.copyWith(isSubmitting: true, clearError: true, needsCredits: false);
    try {
      final result = await ref.read(model3dRepositoryProvider).requestModel3D(tryonId);
      if (!result.existing) ref.read(analyticsServiceProvider).logModel3DRequested();
      if (ref.mounted) state = state.copyWith(isSubmitting: false, modelId: result.modelId);
      return result.modelId;
    } catch (e, st) {
      if (e is! AppException) ref.read(crashlyticsServiceProvider).recordError(e, st);
      if (ref.mounted) {
        state = state.copyWith(isSubmitting: false, error: ErrorMapper.map(e).message, needsCredits: e is InsufficientCreditsException);
      }
      return null;
    }
  }

  void clearError() => state = state.copyWith(clearError: true, needsCredits: false);
}
