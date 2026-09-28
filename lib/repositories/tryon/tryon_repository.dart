import 'dart:io';

import '../../core/constants/app_constants.dart';
import '../../core/constants/firestore_paths.dart';
import '../../core/constants/functions_names.dart';
import '../../core/enums/enums.dart';
import '../../core/utils/paged_state.dart';
import '../../models/tryon/tryon_job_model.dart';
import '../../services/firebase/firestore_service.dart';
import '../../services/firebase/functions_service.dart';
import '../../services/firebase/storage_service.dart';
import '../../services/media/local_files.dart';

class TryOnRepository {
  TryOnRepository(this._db, this._storage, this._functions);

  final FirestoreService _db;
  final StorageService _storage;
  final FunctionsService _functions;

  /// Krediyi sunucuda atomik düşer ve işi kuyruğa alır.
  Future<TryOnRequestResult> requestTryOn({
    required String photoId,
    required String garmentId,
    required bool multiView,
    TryOnProviderChoice? provider,
  }) async {
    final res = await _functions.call(FunctionNames.requestTryOn, {
      'photoId': photoId,
      'garmentId': garmentId,
      'multiView': multiView,
      if (provider != null) 'provider': provider.value,
    });
    return TryOnRequestResult.fromMap(res);
  }

  Stream<TryOnJobModel?> watchJob(String uid, String jobId) => _db.watchTyped(FirestorePaths.tryon(uid, jobId), TryOnJobModel.fromMap);

  Future<PageResult<TryOnJobModel>> getHistory(String uid, {Object? cursor, int limit = AppConstants.historyPageSize}) => _db.getPage(
    _db.collection(FirestorePaths.userTryons(uid)).orderBy('createdAt', descending: true),
    limit: limit,
    cursor: cursor,
    mapper: TryOnJobModel.fromMap,
  );

  /// Yalnızca tamamlanmış/başarısız işler silinebilir (kurallar). Dosyaları sunucu temizler.
  Future<void> deleteJob(String uid, String jobId) => _db.deleteDoc(FirestorePaths.tryon(uid, jobId));

  /// Paylaşım için sonucu geçici dosyaya indirir.
  Future<File> downloadResult(String storagePath) async {
    final name = storagePath.split('/').skip(3).join('_');
    final file = await LocalFiles.shareFile(name.isEmpty ? 'kabin.jpg' : name);
    if (await file.exists() && await file.length() > 0) return file;
    return _storage.downloadToFile(storagePath, file);
  }
}
