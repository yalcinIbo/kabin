import 'dart:io';

import '../../core/constants/firestore_paths.dart';
import '../../core/constants/functions_names.dart';
import '../../core/errors/errors.dart';
import '../../models/model3d/model3d_model.dart';
import '../../services/firebase/firestore_service.dart';
import '../../services/firebase/functions_service.dart';
import '../../services/firebase/storage_service.dart';
import '../../services/media/local_files.dart';

class Model3DRepository {
  Model3DRepository(this._db, this._storage, this._functions);

  final FirestoreService _db;
  final StorageService _storage;
  final FunctionsService _functions;

  Future<Model3DRequestResult> requestModel3D(String tryonId) async {
    final res = await _functions.call(FunctionNames.requestModel3D, {'tryonId': tryonId});
    return Model3DRequestResult.fromMap(res);
  }

  Stream<Model3DModel?> watchModel(String uid, String modelId) =>
      _db.watchTyped(FirestorePaths.model3d(uid, modelId), Model3DModel.fromMap);

  /// GLB'yi cihaza indirir (görüntüleyici `file://` ile CORS'suz yükler). Önbellekte varsa onu döner.
  Future<File> localGlb(Model3DModel model) async {
    final path = model.glbPath;
    if (path == null) throw const NotFoundException('3D model dosyası henüz hazır değil.');
    final file = await LocalFiles.modelFile(model.id);
    if (await file.exists() && await file.length() > 0) return file;
    return _storage.downloadToFile(path, file);
  }

  Future<void> deleteModel(String uid, String modelId) async {
    await _db.deleteDoc(FirestorePaths.model3d(uid, modelId));
    final file = await LocalFiles.modelFile(modelId);
    if (await file.exists()) await file.delete();
  }
}
