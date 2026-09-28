import '../../core/utils/paged_state.dart';
import '../../models/tryon/tryon_job_model.dart';
import '../../providers/tryon/tryon_providers.dart';
import '../common/paged_notifier.dart';

/// Geçmiş sekmesi: denemeler (yeniden eskiye, sayfalı).
class TryOnHistoryNotifier extends PagedNotifier<TryOnJobModel> {
  @override
  Future<PageResult<TryOnJobModel>> fetchPage(String uid, Object? cursor) =>
      ref.read(tryOnRepositoryProvider).getHistory(uid, cursor: cursor);

  Future<String?> delete(String jobId) => runAction(() async {
    final id = uid;
    if (id == null) return;
    await ref.read(tryOnRepositoryProvider).deleteJob(id, jobId);
    removeWhere((j) => j.id == jobId);
  });
}
