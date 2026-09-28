import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/errors.dart';
import '../../models/garment/garment_model.dart';
import '../../providers/auth/auth_providers.dart';
import '../../providers/garment/garment_providers.dart';

class GarmentEditState {
  const GarmentEditState({this.isSaving = false, this.isDeleting = false, this.deleted = false, this.error, this.savedAt});

  final bool isSaving;
  final bool isDeleting;
  final bool deleted;
  final String? error;
  final DateTime? savedAt;

  GarmentEditState copyWith({bool? isSaving, bool? isDeleting, bool? deleted, String? error, bool clearError = false, DateTime? savedAt}) =>
      GarmentEditState(
        isSaving: isSaving ?? this.isSaving,
        isDeleting: isDeleting ?? this.isDeleting,
        deleted: deleted ?? this.deleted,
        error: clearError ? null : (error ?? this.error),
        savedAt: savedAt ?? this.savedAt,
      );
}

/// Kıyafet detayında analiz düzeltme ve silme.
class GarmentEditNotifier extends Notifier<GarmentEditState> {
  GarmentEditNotifier(this.garmentId);

  final String garmentId;

  @override
  GarmentEditState build() => const GarmentEditState();

  Future<bool> save(GarmentAnalysisModel analysis) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return false;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await ref.read(garmentRepositoryProvider).updateAnalysis(uid, garmentId, analysis);
      ref.invalidate(garmentsNotifierProvider);
      if (ref.mounted) state = state.copyWith(isSaving: false, savedAt: DateTime.now());
      return true;
    } catch (e) {
      if (ref.mounted) state = state.copyWith(isSaving: false, error: ErrorMapper.map(e).message);
      return false;
    }
  }

  Future<bool> delete() async {
    state = state.copyWith(isDeleting: true, clearError: true);
    final error = await ref.read(garmentsNotifierProvider.notifier).delete(garmentId);
    if (!ref.mounted) return error == null;
    state = state.copyWith(isDeleting: false, deleted: error == null, error: error);
    return error == null;
  }

  void clearError() => state = state.copyWith(clearError: true);
}
