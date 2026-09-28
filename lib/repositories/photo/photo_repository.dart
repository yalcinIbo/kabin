import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' show Query;
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/firestore_paths.dart';
import '../../core/constants/functions_names.dart';
import '../../core/constants/storage_paths.dart';
import '../../core/errors/errors.dart';
import '../../core/utils/paged_state.dart';
import '../../models/photo/photo_model.dart';
import '../../models/user/user_model.dart';
import '../../services/firebase/firestore_service.dart';
import '../../services/firebase/functions_service.dart';
import '../../services/firebase/storage_service.dart';
import '../../services/media/image_service.dart';

/// `checkPhoto` sonucu.
class PhotoCheckResult {
  const PhotoCheckResult({required this.ready, required this.qc, required this.isDefault});

  final bool ready;
  final PhotoQcModel? qc;
  final bool isDefault;
}

/// Kullanıcının boydan fotoğrafları ve selfie → stüdyo avatar akışı.
class PhotoRepository {
  PhotoRepository(this._db, this._storage, this._functions, this._images);

  final FirestoreService _db;
  final StorageService _storage;
  final FunctionsService _functions;
  final ImageService _images;
  static const _uuid = Uuid();

  Query<DocData> _photos(String uid) => _db.collection(FirestorePaths.userPhotos(uid)).orderBy('createdAt', descending: true);

  Stream<PhotoModel?> watchPhoto(String uid, String photoId) => _db.watchTyped(FirestorePaths.photo(uid, photoId), PhotoModel.fromMap);

  Future<PhotoModel?> getPhoto(String uid, String photoId) => _db.getTyped(FirestorePaths.photo(uid, photoId), PhotoModel.fromMap);

  Stream<PhotoModel?> watchDefaultPhoto(String uid) => _db
      .watchList(_db.collection(FirestorePaths.userPhotos(uid)).where('isDefault', isEqualTo: true).limit(1), PhotoModel.fromMap)
      .map((list) => list.isEmpty ? null : list.first);

  Future<PageResult<PhotoModel>> getPhotos(String uid, {Object? cursor, int limit = AppConstants.gridPageSize}) =>
      _db.getPage(_photos(uid), limit: limit, cursor: cursor, mapper: PhotoModel.fromMap);

  /// Sıkıştırır, orijinal + küçük resmi yükler ve `pending` belge oluşturur. Belge id'sini döner.
  Future<String> uploadPhoto(String uid, File file, {ProgressCallback? onProgress}) async {
    final photoId = _db.newId(FirestorePaths.userPhotos(uid));
    final processed = await _images.compress(file);
    final thumb = await _images.thumbnail(processed.file);
    final original = StoragePaths.photoOriginal(uid, photoId);
    final thumbPath = StoragePaths.photoThumb(uid, photoId);
    await _storage.uploadFile(path: original, file: processed.file, onProgress: (p) => onProgress?.call(p * 0.9));
    await _storage.uploadFile(path: thumbPath, file: thumb.file);
    onProgress?.call(1);
    await _db.setDoc(FirestorePaths.photo(uid, photoId), {
      'source': 'upload',
      'status': 'pending',
      'storagePath': original,
      'thumbPath': thumbPath,
      'width': processed.width,
      'height': processed.height,
      'isDefault': false,
      'createdAt': _db.serverTimestamp,
      'updatedAt': _db.serverTimestamp,
    });
    return photoId;
  }

  /// Gemini kalite kontrolü (sunucu). Geçerse fotoğraf `ready` olur.
  Future<PhotoCheckResult> checkPhoto(String photoId) async {
    final res = await _functions.call(FunctionNames.checkPhoto, {'photoId': photoId});
    return PhotoCheckResult(ready: res['status'] == 'ready', qc: PhotoQcModel.fromMap(res['qc']), isDefault: res['isDefault'] == true);
  }

  Future<void> setDefault(String uid, String photoId) async {
    final current = await _db.getList(
      _db.collection(FirestorePaths.userPhotos(uid)).where('isDefault', isEqualTo: true).limit(10),
      PhotoModel.fromMap,
    );
    final batch = _db.batch();
    for (final p in current.where((p) => p.id != photoId)) {
      batch.update(_db.doc(FirestorePaths.photo(uid, p.id)), {'isDefault': false, 'updatedAt': _db.serverTimestamp});
    }
    batch.update(_db.doc(FirestorePaths.photo(uid, photoId)), {'isDefault': true, 'updatedAt': _db.serverTimestamp});
    await _db.commitBatch(batch);
  }

  /// Belge silinir; Storage dosyalarını sunucu tetikleyicisi temizler.
  Future<void> deletePhoto(String uid, String photoId) => _db.deleteDoc(FirestorePaths.photo(uid, photoId));

  /// Selfie'yi geçici klasöre yükler (üretimden sonra sunucu siler).
  Future<String> uploadSelfie(String uid, File file, {ProgressCallback? onProgress}) async {
    final processed = await _images.compress(file, maxDimension: AppConstants.selfieMaxDimension);
    final path = StoragePaths.tmpSelfie(uid, _uuid.v4());
    await _storage.uploadFile(path: path, file: processed.file, onProgress: onProgress);
    return path;
  }

  /// Selfie + ölçülerden stüdyo avatar üretimini başlatır. Yeni fotoğraf id'sini döner.
  Future<String> generateAvatar({required String selfiePath, required Measurements measurements}) async {
    if (!measurements.isComplete) {
      throw const ValidationException('Boy, kilo ve vücut tipi gerekli.', code: 'measurements-required');
    }
    final res = await _functions.call(FunctionNames.generateAvatar, {
      'selfiePath': selfiePath,
      'heightCm': measurements.heightCm,
      'weightKg': measurements.weightKg,
      'bodyType': measurements.bodyType!.value,
      'gender': measurements.gender.value,
    });
    return res['photoId'] as String;
  }
}
