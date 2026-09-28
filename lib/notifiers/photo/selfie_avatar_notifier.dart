import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/errors.dart';
import '../../models/user/user_model.dart';
import '../../providers/auth/auth_providers.dart';
import '../../providers/core/core_providers.dart';
import '../../providers/photo/photo_providers.dart';
import '../../providers/user/user_providers.dart';
import '../../services/media/image_service.dart';

class SelfieAvatarState {
  const SelfieAvatarState({
    this.selfie,
    this.measurements = const Measurements(),
    this.isSubmitting = false,
    this.progress = 0,
    this.photoId,
    this.error,
    this.needsCredits = false,
  });

  final File? selfie;
  final Measurements measurements;
  final bool isSubmitting;
  final double progress;
  final String? photoId;
  final String? error;
  final bool needsCredits;

  bool get canSubmit => selfie != null && measurements.isComplete && !isSubmitting;

  SelfieAvatarState copyWith({
    File? selfie,
    Measurements? measurements,
    bool? isSubmitting,
    double? progress,
    String? photoId,
    String? error,
    bool clearError = false,
    bool? needsCredits,
  }) => SelfieAvatarState(
    selfie: selfie ?? this.selfie,
    measurements: measurements ?? this.measurements,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    progress: progress ?? this.progress,
    photoId: photoId ?? this.photoId,
    error: clearError ? null : (error ?? this.error),
    needsCredits: needsCredits ?? this.needsCredits,
  );
}

/// Selfie + ölçüler → sunucuda stüdyo tipi boydan fotoğraf üretimi.
class SelfieAvatarNotifier extends Notifier<SelfieAvatarState> {
  @override
  SelfieAvatarState build() => SelfieAvatarState(measurements: ref.read(currentUserProvider).value?.measurements ?? const Measurements());

  Future<void> pickSelfie(PickSource source) async {
    try {
      final file = await ref.read(imageServiceProvider).pick(source, preferFrontCamera: true);
      if (file != null && ref.mounted) state = state.copyWith(selfie: file, clearError: true);
    } catch (e) {
      if (ref.mounted) state = state.copyWith(error: ErrorMapper.map(e).message);
    }
  }

  void setMeasurements(Measurements value) => state = state.copyWith(measurements: value, clearError: true);

  Future<String?> submit() async {
    final uid = ref.read(currentUidProvider);
    final selfie = state.selfie;
    if (uid == null || selfie == null || !state.canSubmit) {
      if (!state.measurements.isComplete) state = state.copyWith(error: 'Boy, kilo ve vücut tipini seç.');
      return null;
    }
    state = state.copyWith(isSubmitting: true, progress: 0, clearError: true, needsCredits: false);
    try {
      final repo = ref.read(photoRepositoryProvider);
      final path = await repo.uploadSelfie(
        uid,
        selfie,
        onProgress: (p) {
          if (ref.mounted) state = state.copyWith(progress: p);
        },
      );
      final photoId = await repo.generateAvatar(selfiePath: path, measurements: state.measurements);
      ref.read(analyticsServiceProvider).logPhotoAdded('avatar');
      ref.invalidate(photosNotifierProvider);
      if (ref.mounted) state = state.copyWith(isSubmitting: false, photoId: photoId);
      return photoId;
    } catch (e, st) {
      if (e is! AppException) ref.read(crashlyticsServiceProvider).recordError(e, st);
      if (ref.mounted) {
        state = state.copyWith(isSubmitting: false, error: ErrorMapper.map(e).message, needsCredits: e is InsufficientCreditsException);
      }
      return null;
    }
  }
}
