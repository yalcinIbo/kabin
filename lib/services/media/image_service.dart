import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/errors.dart';

/// İşlenmiş görsel sonucu.
class ProcessedImage {
  const ProcessedImage({required this.file, required this.width, required this.height, required this.sizeBytes});

  final File file;
  final int width;
  final int height;
  final int sizeBytes;
}

enum PickSource { camera, gallery }

/// Görsel seçme ve sıkıştırma. Upload burada yapılmaz.
class ImageService {
  ImageService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;
  static const _uuid = Uuid();

  Future<File?> pick(PickSource source, {bool preferFrontCamera = false}) async {
    try {
      final x = await _picker.pickImage(
        source: source == PickSource.camera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 100,
        preferredCameraDevice: preferFrontCamera ? CameraDevice.front : CameraDevice.rear,
      );
      return x == null ? null : File(x.path);
    } catch (e) {
      throw MediaException(source == PickSource.camera ? 'Kamera açılamadı. İzinleri kontrol et.' : 'Görsel seçilemedi.', cause: e);
    }
  }

  /// Upload öncesi sıkıştırma. Uzun kenar [maxDimension] ile sınırlanır.
  Future<ProcessedImage> compress(
    File source, {
    int maxDimension = AppConstants.photoMaxDimension,
    int quality = AppConstants.photoQuality,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final target = '${dir.path}/${_uuid.v4()}.jpg';
      final result = await FlutterImageCompress.compressAndGetFile(
        source.absolute.path,
        target,
        minWidth: maxDimension,
        minHeight: maxDimension,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      if (result == null) throw const MediaException('Görsel sıkıştırılamadı.');
      final file = File(result.path);
      final size = await _dimensions(file);
      return ProcessedImage(file: file, width: size.$1, height: size.$2, sizeBytes: await file.length());
    } on AppException {
      rethrow;
    } catch (e) {
      throw MediaException('Görsel işlenemedi.', cause: e);
    }
  }

  Future<ProcessedImage> thumbnail(File source) =>
      compress(source, maxDimension: AppConstants.thumbnailMaxDimension, quality: AppConstants.thumbnailQuality);

  Future<(int, int)> _dimensions(File file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final result = (image.width, image.height);
    image.dispose();
    codec.dispose();
    return result;
  }
}
