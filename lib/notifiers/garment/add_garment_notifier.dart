import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/errors.dart';
import '../../models/garment/garment_model.dart';
import '../../providers/auth/auth_providers.dart';
import '../../providers/core/core_providers.dart';
import '../../providers/garment/garment_providers.dart';
import '../../providers/tryon/tryon_providers.dart';
import '../../services/media/image_service.dart';

enum AddGarmentStep { pick, uploading, analyzing, review }

class AddGarmentState {
  const AddGarmentState({
    this.file,
    this.step = AddGarmentStep.pick,
    this.progress = 0,
    this.garmentId,
    this.original,
    this.analysis,
    this.analysisFailed = false,
    this.isSaving = false,
    this.saved = false,
    this.error,
  });

  final File? file;
  final AddGarmentStep step;
  final double progress;
  final String? garmentId;

  /// Sunucunun ürettiği analiz; [analysis] kullanıcının düzenlediği hâlidir.
  final GarmentAnalysisModel? original;
  final GarmentAnalysisModel? analysis;
  final bool analysisFailed;
  final bool isSaving;
  final bool saved;
  final String? error;

  bool get isBusy => step == AddGarmentStep.uploading || step == AddGarmentStep.analyzing || isSaving;

  AddGarmentState copyWith({
    File? file,
    AddGarmentStep? step,
    double? progress,
    String? garmentId,
    GarmentAnalysisModel? original,
    GarmentAnalysisModel? analysis,
    bool? analysisFailed,
    bool? isSaving,
    bool? saved,
    String? error,
    bool clearError = false,
  }) => AddGarmentState(
    file: file ?? this.file,
    step: step ?? this.step,
    progress: progress ?? this.progress,
    garmentId: garmentId ?? this.garmentId,
    original: original ?? this.original,
    analysis: analysis ?? this.analysis,
    analysisFailed: analysisFailed ?? this.analysisFailed,
    isSaving: isSaving ?? this.isSaving,
    saved: saved ?? this.saved,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Kıyafet ekleme: seç → yükle → Gemini analizi → kullanıcı düzeltmesi → kaydet.
class AddGarmentNotifier extends Notifier<AddGarmentState> {
  @override
  AddGarmentState build() => const AddGarmentState();

  Future<void> pick(PickSource source) async {
    try {
      final file = await ref.read(imageServiceProvider).pick(source);
      if (file != null && ref.mounted) state = AddGarmentState(file: file);
    } catch (e) {
      if (ref.mounted) state = state.copyWith(error: ErrorMapper.map(e).message);
    }
  }

  Future<void> submit() async {
    final uid = ref.read(currentUidProvider);
    final file = state.file;
    if (uid == null || file == null || state.isBusy) return;
    state = state.copyWith(step: AddGarmentStep.uploading, progress: 0, clearError: true);
    try {
      final id = await ref
          .read(garmentRepositoryProvider)
          .uploadGarment(
            uid,
            file,
            onProgress: (p) {
              if (ref.mounted) state = state.copyWith(progress: p);
            },
          );
      if (!ref.mounted) return;
      state = state.copyWith(garmentId: id);
      await _analyze(id);
    } catch (e, st) {
      _fail(e, st, AddGarmentStep.pick);
    }
  }

  Future<void> retryAnalyze() async {
    final id = state.garmentId;
    if (id == null || state.isBusy) return;
    await _analyze(id);
  }

  Future<void> _analyze(String garmentId) async {
    state = state.copyWith(step: AddGarmentStep.analyzing, clearError: true);
    try {
      final result = await ref.read(garmentRepositoryProvider).analyzeGarment(garmentId);
      if (!ref.mounted) return;
      state = state.copyWith(
        step: AddGarmentStep.review,
        original: result.analysis,
        analysis: result.analysis,
        analysisFailed: !result.ready,
        error: result.ready ? null : 'Fotoğrafta bir kıyafet algılanamadı. Kıyafeti tek başına ve net çek.',
      );
      ref.invalidate(garmentsNotifierProvider);
      if (result.analysis != null) ref.read(analyticsServiceProvider).logGarmentAdded(result.analysis!.category.value);
    } catch (e, st) {
      _fail(e, st, AddGarmentStep.review);
    }
  }

  void updateAnalysis(GarmentAnalysisModel analysis) => state = state.copyWith(analysis: analysis, clearError: true);

  /// Kullanıcı analizi değiştirdiyse kaydeder; değişiklik yoksa doğrudan tamamlar.
  Future<bool> save() async {
    final uid = ref.read(currentUidProvider);
    final id = state.garmentId;
    final analysis = state.analysis;
    if (uid == null || id == null || analysis == null) return false;
    final changed =
        analysis != state.original &&
        (analysis.titleTr != state.original?.titleTr ||
            analysis.category != state.original?.category ||
            analysis.garmentPhotoType != state.original?.garmentPhotoType ||
            analysis.colorNameTr != state.original?.colorNameTr);
    if (!changed) {
      state = state.copyWith(saved: true);
      return true;
    }
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await ref.read(garmentRepositoryProvider).updateAnalysis(uid, id, analysis);
      ref.invalidate(garmentsNotifierProvider);
      if (ref.mounted) state = state.copyWith(isSaving: false, saved: true);
      return true;
    } catch (e) {
      if (ref.mounted) state = state.copyWith(isSaving: false, error: ErrorMapper.map(e).message);
      return false;
    }
  }

  /// Kaydeder ve kıyafeti Dene ekranında seçili hâle getirir.
  Future<bool> saveAndSelectForTryOn() async {
    if (!await save()) return false;
    final uid = ref.read(currentUidProvider);
    final id = state.garmentId;
    if (uid == null || id == null) return false;
    try {
      final garment = await ref.read(garmentRepositoryProvider).getGarment(uid, id);
      if (garment != null) ref.read(tryOnRequestNotifierProvider.notifier).selectGarment(garment);
      return true;
    } catch (e) {
      if (ref.mounted) state = state.copyWith(error: ErrorMapper.map(e).message);
      return false;
    }
  }

  void reset() => state = const AddGarmentState();

  void _fail(Object e, StackTrace st, AddGarmentStep step) {
    if (e is! AppException) ref.read(crashlyticsServiceProvider).recordError(e, st);
    if (ref.mounted) state = state.copyWith(step: step, error: ErrorMapper.map(e).message);
  }
}
