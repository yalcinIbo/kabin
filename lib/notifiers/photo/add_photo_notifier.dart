import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/errors.dart';
import '../../providers/auth/auth_providers.dart';
import '../../providers/core/core_providers.dart';
import '../../providers/photo/photo_providers.dart';
import '../../providers/tryon/tryon_providers.dart';
import '../../repositories/photo/photo_repository.dart';
import '../../services/media/image_service.dart';

enum AddPhotoStep { pick, uploading, checking, result }

class AddPhotoState {
  const AddPhotoState({this.file, this.step = AddPhotoStep.pick, this.progress = 0, this.photoId, this.result, this.error});

  final File? file;
  final AddPhotoStep step;
  final double progress;
  final String? photoId;
  final PhotoCheckResult? result;
  final String? error;

  bool get isBusy => step == AddPhotoStep.uploading || step == AddPhotoStep.checking;
  bool get passed => result?.ready ?? false;

  AddPhotoState copyWith({
    File? file,
    AddPhotoStep? step,
    double? progress,
    String? photoId,
    PhotoCheckResult? result,
    String? error,
    bool clearError = false,
    bool clearResult = false,
  }) => AddPhotoState(
    file: file ?? this.file,
    step: step ?? this.step,
    progress: progress ?? this.progress,
    photoId: photoId ?? this.photoId,
    result: clearResult ? null : (result ?? this.result),
    error: clearError ? null : (error ?? this.error),
  );
}

/// Boydan fotoğraf ekleme: seç → yükle → Gemini kalite kontrolü → sonuç.
class AddPhotoNotifier extends Notifier<AddPhotoState> {
  @override
  AddPhotoState build() => const AddPhotoState();

  Future<void> pick(PickSource source) async {
    try {
      final file = await ref.read(imageServiceProvider).pick(source);
      if (file == null || !ref.mounted) return;
      state = AddPhotoState(file: file);
    } catch (e) {
      if (ref.mounted) state = state.copyWith(error: ErrorMapper.map(e).message);
    }
  }

  Future<void> submit() async {
    final file = state.file;
    final uid = ref.read(currentUidProvider);
    if (file == null || uid == null || state.isBusy) return;
    state = state.copyWith(step: AddPhotoStep.uploading, progress: 0, clearError: true, clearResult: true);
    try {
      final repo = ref.read(photoRepositoryProvider);
      final photoId = await repo.uploadPhoto(
        uid,
        file,
        onProgress: (p) {
          if (ref.mounted) state = state.copyWith(progress: p);
        },
      );
      if (!ref.mounted) return;
      state = state.copyWith(photoId: photoId);
      await _check(photoId);
      ref.read(analyticsServiceProvider).logPhotoAdded('upload');
    } catch (e, st) {
      _fail(e, st, AddPhotoStep.pick);
    }
  }

  /// Kalite kontrolü bir ağ hatası yüzünden tamamlanmadıysa tekrar dener.
  Future<void> retryCheck() async {
    final photoId = state.photoId;
    if (photoId == null || state.isBusy) return;
    await _check(photoId);
  }

  Future<void> _check(String photoId) async {
    state = state.copyWith(step: AddPhotoStep.checking, clearError: true);
    try {
      final result = await ref.read(photoRepositoryProvider).checkPhoto(photoId);
      if (!ref.mounted) return;
      state = state.copyWith(step: AddPhotoStep.result, result: result);
      ref.invalidate(photosNotifierProvider);
      if (state.passed) await _selectForTryOn(photoId);
    } catch (e, st) {
      _fail(e, st, AddPhotoStep.result);
    }
  }

  /// Kontrolden geçen yeni fotoğraf Dene ekranında seçili olur; kullanıcı yeniden seçmek zorunda kalmaz.
  /// En iyi çaba: seçilemezse akış bozulmaz, kullanıcı elle seçebilir.
  Future<void> _selectForTryOn(String photoId) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    try {
      final photo = await ref.read(photoRepositoryProvider).getPhoto(uid, photoId);
      if (photo != null && ref.mounted) ref.read(tryOnRequestNotifierProvider.notifier).selectPhoto(photo);
    } catch (_) {}
  }

  void reset() => state = const AddPhotoState();

  void _fail(Object e, StackTrace st, AddPhotoStep step) {
    if (e is! AppException) ref.read(crashlyticsServiceProvider).recordError(e, st);
    if (ref.mounted) state = state.copyWith(step: step, error: ErrorMapper.map(e).message);
  }
}
