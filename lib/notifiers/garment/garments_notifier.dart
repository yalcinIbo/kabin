import '../../core/utils/paged_state.dart';
import '../../models/garment/garment_model.dart';
import '../../providers/garment/garment_providers.dart';
import '../common/paged_notifier.dart';

/// Dolabım > Kıyafetler listesi (sayfalı).
class GarmentsNotifier extends PagedNotifier<GarmentModel> {
  @override
  Future<PageResult<GarmentModel>> fetchPage(String uid, Object? cursor) =>
      ref.read(garmentRepositoryProvider).getGarments(uid, cursor: cursor);

  Future<String?> delete(String garmentId) => runAction(() async {
    final id = uid;
    if (id == null) return;
    await ref.read(garmentRepositoryProvider).deleteGarment(id, garmentId);
    removeWhere((g) => g.id == garmentId);
  });
}
