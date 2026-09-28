import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../../core/errors/errors.dart';

typedef ProgressCallback = void Function(double progress);

/// Firebase Storage erişimi. Dosya sıkıştırma burada yapılmaz (media servisleri).
/// Belgeler URL değil **yol** (storagePath) saklar; URL gerektiğinde [getDownloadUrl] ile çözülür.
class StorageService {
  StorageService({FirebaseStorage? storage}) : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;
  final Map<String, UploadTask> _activeTasks = {};

  Future<void> uploadFile({
    required String path,
    required File file,
    String contentType = 'image/jpeg',
    ProgressCallback? onProgress,
  }) async {
    final task = _storage.ref(path).putFile(file, SettableMetadata(contentType: contentType, cacheControl: 'private, max-age=31536000'));
    _activeTasks[path] = task;
    try {
      if (onProgress != null) {
        task.snapshotEvents.listen((s) {
          if (s.totalBytes > 0) onProgress(s.bytesTransferred / s.totalBytes);
        }, onError: (_) {});
      }
      await task;
    } catch (e) {
      throw ErrorMapper.map(e);
    } finally {
      _activeTasks.remove(path);
    }
  }

  Future<String> getDownloadUrl(String path) async {
    try {
      return await _storage.ref(path).getDownloadURL();
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  /// Dosyayı yerel diske indirir (paylaşım ve 3D görüntüleyici için).
  Future<File> downloadToFile(String path, File target) async {
    try {
      await target.parent.create(recursive: true);
      await _storage.ref(path).writeToFile(target);
      return target;
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<Uint8List?> getBytes(String path, {int maxSize = 20 * 1024 * 1024}) async {
    try {
      return await _storage.ref(path).getData(maxSize);
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<void> cancelUpload(String path) async {
    await _activeTasks[path]?.cancel();
    _activeTasks.remove(path);
  }

  Future<void> deleteByPath(String path) async {
    try {
      await _storage.ref(path).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return;
      throw ErrorMapper.map(e);
    }
  }
}
