import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums/enums.dart';
import '../../core/errors/errors.dart';
import '../../models/garment/garment_model.dart';
import '../../models/photo/photo_model.dart';
import '../../providers/auth/auth_providers.dart';
import '../../providers/core/core_providers.dart';
import '../../providers/tryon/tryon_providers.dart';

class TryOnRequestState {
  const TryOnRequestState({
    this.photo,
    this.garment,
    this.multiView = true,
    this.provider,
    this.isSubmitting = false,
    this.error,
    this.needsCredits = false,
    this.createdJobId,
  });

  final PhotoModel? photo;
  final GarmentModel? garment;
  final bool multiView;

  /// Yalnızca yönetici: sağlayıcı karşılaştırması.
  final TryOnProviderChoice? provider;
  final bool isSubmitting;
  final String? error;
  final bool needsCredits;
  final String? createdJobId;

  bool get canSubmit => (photo?.isReady ?? false) && (garment?.canTryOn ?? false) && !isSubmitting;

  TryOnRequestState copyWith({
    PhotoModel? photo,
    GarmentModel? garment,
    bool? multiView,
    TryOnProviderChoice? provider,
    bool clearProvider = false,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    bool? needsCredits,
    String? createdJobId,
    bool clearCreatedJob = false,
  }) => TryOnRequestState(
    photo: photo ?? this.photo,
    garment: garment ?? this.garment,
    multiView: multiView ?? this.multiView,
    provider: clearProvider ? null : (provider ?? this.provider),
    isSubmitting: isSubmitting ?? this.isSubmitting,
    error: clearError ? null : (error ?? this.error),
    needsCredits: needsCredits ?? this.needsCredits,
    createdJobId: clearCreatedJob ? null : (createdJobId ?? this.createdJobId),
  );
}

/// Dene ekranı: fotoğraf + kıyafet seçimi ve deneme isteği.
class TryOnRequestNotifier extends Notifier<TryOnRequestState> {
  @override
  TryOnRequestState build() {
    // Oturum değişince (çıkış / başka hesap) seçim sıfırlanır; başka hesabın görselleri görünmez.
    ref.watch(currentUidProvider);
    return const TryOnRequestState();
  }

  void selectPhoto(PhotoModel photo) => state = state.copyWith(photo: photo, clearError: true, needsCredits: false);
  void selectGarment(GarmentModel garment) => state = state.copyWith(garment: garment, clearError: true, needsCredits: false);
  void setMultiView(bool value) => state = state.copyWith(multiView: value);
  void setProvider(TryOnProviderChoice? value) =>
      state = value == null ? state.copyWith(clearProvider: true) : state.copyWith(provider: value);

  /// İsteği gönderir; başarılıysa iş kimliğini döner.
  Future<String?> submit() async {
    final photo = state.photo;
    final garment = state.garment;
    if (photo == null || garment == null) {
      state = state.copyWith(error: 'Önce bir fotoğraf ve bir kıyafet seç.');
      return null;
    }
    if (!garment.canTryOn) {
      state = state.copyWith(error: 'Bu kıyafet türü henüz denenemiyor.');
      return null;
    }
    if (state.isSubmitting) return null;
    state = state.copyWith(isSubmitting: true, clearError: true, needsCredits: false, clearCreatedJob: true);
    try {
      final result = await ref
          .read(tryOnRepositoryProvider)
          .requestTryOn(photoId: photo.id, garmentId: garment.id, multiView: state.multiView, provider: state.provider);
      ref.read(analyticsServiceProvider).logTryOnRequested(multiView: state.multiView, cost: result.cost);
      ref.invalidate(tryOnHistoryNotifierProvider);
      state = state.copyWith(isSubmitting: false, createdJobId: result.jobId);
      return result.jobId;
    } catch (e, st) {
      if (e is! AppException) ref.read(crashlyticsServiceProvider).recordError(e, st);
      state = state.copyWith(isSubmitting: false, error: ErrorMapper.map(e).message, needsCredits: e is InsufficientCreditsException);
      return null;
    }
  }

  /// Seçilen öğe silindiyse seçimi temizler.
  void forgetGarment(String garmentId) {
    if (state.garment?.id == garmentId) state = TryOnRequestState(photo: state.photo, multiView: state.multiView, provider: state.provider);
  }

  void forgetPhoto(String photoId) {
    if (state.photo?.id == photoId) state = TryOnRequestState(garment: state.garment, multiView: state.multiView, provider: state.provider);
  }

  void clearError() => state = state.copyWith(clearError: true, needsCredits: false);
}
