import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/errors.dart';
import '../../models/tryon/tryon_job_model.dart';
import '../../providers/core/core_providers.dart';
import '../../providers/tryon/tryon_providers.dart';

class TryOnResultActionsState {
  const TryOnResultActionsState({this.isSharing = false, this.isDeleting = false, this.deleted = false, this.error});

  final bool isSharing;
  final bool isDeleting;
  final bool deleted;
  final String? error;

  TryOnResultActionsState copyWith({bool? isSharing, bool? isDeleting, bool? deleted, String? error, bool clearError = false}) =>
      TryOnResultActionsState(
        isSharing: isSharing ?? this.isSharing,
        isDeleting: isDeleting ?? this.isDeleting,
        deleted: deleted ?? this.deleted,
        error: clearError ? null : (error ?? this.error),
      );
}

/// Sonuç ekranı aksiyonları: paylaş, sil.
class TryOnResultActionsNotifier extends Notifier<TryOnResultActionsState> {
  TryOnResultActionsNotifier(this.jobId);

  final String jobId;

  @override
  TryOnResultActionsState build() => const TryOnResultActionsState();

  Future<void> share(TryOnResultModel result, {String? title}) async {
    if (state.isSharing) return;
    state = state.copyWith(isSharing: true, clearError: true);
    try {
      final file = await ref.read(tryOnRepositoryProvider).downloadResult(result.storagePath);
      await ref.read(shareServiceProvider).shareFile(file, text: title == null ? 'Kabin ile denedim ✨' : '$title · Kabin ile denedim ✨');
      ref.read(analyticsServiceProvider).logShare('tryon', jobId);
      if (ref.mounted) state = state.copyWith(isSharing: false);
    } catch (e) {
      if (ref.mounted) state = state.copyWith(isSharing: false, error: ErrorMapper.map(e).message);
    }
  }

  Future<bool> delete() async {
    state = state.copyWith(isDeleting: true, clearError: true);
    final error = await ref.read(tryOnHistoryNotifierProvider.notifier).delete(jobId);
    if (!ref.mounted) return error == null;
    state = state.copyWith(isDeleting: false, deleted: error == null, error: error);
    return error == null;
  }

  void clearError() => state = state.copyWith(clearError: true);
}
