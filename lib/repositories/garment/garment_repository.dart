import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' show Query;

import '../../core/constants/app_constants.dart';
import '../../core/constants/firestore_paths.dart';
import '../../core/constants/functions_names.dart';
import '../../core/constants/storage_paths.dart';
import '../../core/errors/errors.dart';
import '../../core/utils/paged_state.dart';
import '../../core/utils/validators.dart';
import '../../models/garment/garment_model.dart';
import '../../services/firebase/firestore_service.dart';
import '../../services/firebase/functions_service.dart';
import '../../services/firebase/storage_service.dart';
import '../../services/media/image_service.dart';

/// `analyzeGarment` sonucu.
class GarmentAnalysisResult {
  const GarmentAnalysisResult({required this.ready, required this.analysis, required this.tryonSupported});

  final bool ready;
  final GarmentAnalysisModel? analysis;
  final bool tryonSupported;
}

class GarmentRepository {
  GarmentRepository(this._db, this._storage, this._functions, this._images);

  final FirestoreService _db;
  final StorageService _storage;
  final FunctionsService _functions;
  final ImageService _images;

  Query<DocData> _garments(String uid) => _db.collection(FirestorePaths.userGarments(uid)).orderBy('createdAt', descending: true);

  Stream<GarmentModel?> watchGarment(String uid, String garmentId) =>
      _db.watchTyped(FirestorePaths.garment(uid, garmentId), GarmentModel.fromMap);

  Future<GarmentModel?> getGarment(String uid, String garmentId) =>
      _db.getTyped(FirestorePaths.garment(uid, garmentId), GarmentModel.fromMap);

  Future<PageResult<GarmentModel>> getGarments(String uid, {Object? cursor, int limit = AppConstants.gridPageSize}) =>
      _db.getPage(_garments(uid), limit: limit, cursor: cursor, mapper: GarmentModel.fromMap);

  /// Kıyafet fotoğrafını yükler, `analyzing` belge oluşturur. Belge id'sini döner.
  Future<String> uploadGarment(String uid, File file, {ProgressCallback? onProgress}) async {
    final garmentId = _db.newId(FirestorePaths.userGarments(uid));
    final processed = await _images.compress(file);
    final thumb = await _images.thumbnail(processed.file);
    final original = StoragePaths.garmentOriginal(uid, garmentId);
    final thumbPath = StoragePaths.garmentThumb(uid, garmentId);
    await _storage.uploadFile(path: original, file: processed.file, onProgress: (p) => onProgress?.call(p * 0.9));
    await _storage.uploadFile(path: thumbPath, file: thumb.file);
    onProgress?.call(1);
    await _db.setDoc(FirestorePaths.garment(uid, garmentId), {
      'status': 'analyzing',
      'storagePath': original,
      'thumbPath': thumbPath,
      'userEdited': false,
      'createdAt': _db.serverTimestamp,
      'updatedAt': _db.serverTimestamp,
    });
    return garmentId;
  }

  Future<GarmentAnalysisResult> analyzeGarment(String garmentId) async {
    final res = await _functions.call(FunctionNames.analyzeGarment, {'garmentId': garmentId});
    return GarmentAnalysisResult(
      ready: res['status'] == 'ready',
      analysis: GarmentAnalysisModel.fromMap(res['analysis']),
      tryonSupported: res['tryonSupported'] == true,
    );
  }

  /// Kullanıcının analiz düzeltmesi (kategori, başlık, renk adı, fotoğraf tipi).
  Future<void> updateAnalysis(String uid, String garmentId, GarmentAnalysisModel analysis) async {
    final error = Validators.garmentTitle(analysis.titleTr);
    if (error != null) throw ValidationException(error);
    await _db.updateDoc(FirestorePaths.garment(uid, garmentId), {
      'analysis': analysis.toMap(),
      'tryonSupported': analysis.category.isTryOnSupported,
      'userEdited': true,
      'updatedAt': _db.serverTimestamp,
    });
  }

  Future<void> deleteGarment(String uid, String garmentId) => _db.deleteDoc(FirestorePaths.garment(uid, garmentId));
}
