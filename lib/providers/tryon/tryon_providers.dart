import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/paged_state.dart';
import '../../models/tryon/tryon_job_model.dart';
import '../../notifiers/tryon/tryon_history_notifier.dart';
import '../../notifiers/tryon/tryon_request_notifier.dart';
import '../../notifiers/tryon/tryon_result_actions_notifier.dart';
import '../../repositories/tryon/tryon_repository.dart';
import '../auth/auth_providers.dart';
import '../core/core_providers.dart';

final tryOnRepositoryProvider = Provider<TryOnRepository>((ref) {
  return TryOnRepository(ref.watch(firestoreServiceProvider), ref.watch(storageServiceProvider), ref.watch(functionsServiceProvider));
});

/// Deneme işinin canlı durumu (ilerleme ekranı).
final tryOnJobProvider = StreamProvider.autoDispose.family<TryOnJobModel?, String>((ref, jobId) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(tryOnRepositoryProvider).watchJob(uid, jobId);
});

/// Dene sekmesindeki seçim; sekme değişse de korunur.
final tryOnRequestNotifierProvider = NotifierProvider<TryOnRequestNotifier, TryOnRequestState>(TryOnRequestNotifier.new);

final tryOnHistoryNotifierProvider = AsyncNotifierProvider<TryOnHistoryNotifier, PagedState<TryOnJobModel>>(TryOnHistoryNotifier.new);

final tryOnResultActionsNotifierProvider = NotifierProvider.autoDispose.family<TryOnResultActionsNotifier, TryOnResultActionsState, String>(
  TryOnResultActionsNotifier.new,
);
