import 'package:flutter/painting.dart';

abstract final class CacheConfig {
  /// Bellek içi image cache sınırı.
  static void configureMemoryCache({int maxSizeMb = 160, int maxImages = 300}) {
    PaintingBinding.instance.imageCache
      ..maximumSizeBytes = maxSizeMb * 1024 * 1024
      ..maximumSize = maxImages;
  }
}
