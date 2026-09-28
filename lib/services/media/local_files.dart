import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Uygulama içi önbellek dosyaları (3D modeller, paylaşılacak görseller).
abstract final class LocalFiles {
  /// Not: flutter_3d_controller `file://` yolunu URL kodlu okuduğu için yolda boşluk olmamalı
  /// ("Application Support" kullanılamaz). Caches klasörü boşluksuzdur; model gerekirse yeniden indirilir.
  static Future<File> modelFile(String modelId) async {
    final dir = await getApplicationCacheDirectory();
    return File('${dir.path}/models3d/$modelId.glb');
  }

  static Future<File> shareFile(String name) async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/share/$name');
  }
}
