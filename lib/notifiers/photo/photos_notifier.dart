import '../../core/utils/paged_state.dart';
import '../../models/photo/photo_model.dart';
import '../../providers/photo/photo_providers.dart';
import '../common/paged_notifier.dart';

/// Dolabım > Fotoğraflarım listesi (sayfalı).
class PhotosNotifier extends PagedNotifier<PhotoModel> {
  @override
  Future<PageResult<PhotoModel>> fetchPage(String uid, Object? cursor) => ref.read(photoRepositoryProvider).getPhotos(uid, cursor: cursor);

  Future<String?> setDefault(String photoId) => runAction(() async {
    final id = uid;
    if (id == null) return;
    await ref.read(photoRepositoryProvider).setDefault(id, photoId);
    await refresh();
  });

  Future<String?> delete(String photoId) => runAction(() async {
    final id = uid;
    if (id == null) return;
    await ref.read(photoRepositoryProvider).deletePhoto(id, photoId);
    removeWhere((p) => p.id == photoId);
  });
}
