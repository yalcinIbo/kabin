import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/core/core_providers.dart';
import '../constants/app_constants.dart';
import 'cached_image.dart';
import 'shimmer_view.dart';

/// Firestore'daki Storage yolundan görsel gösterir (URL önbellekli çözülür).
class StorageImage extends ConsumerWidget {
  const StorageImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.cacheWidth = AppConstants.gridCacheWidth,
    this.borderRadius,
    this.width,
    this.height,
  });

  final String? path;
  final BoxFit fit;
  final int? cacheWidth;
  final BorderRadius? borderRadius;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    Widget fallback(IconData icon) => ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Container(
        width: width,
        height: height,
        color: scheme.surfaceContainerHigh,
        child: Center(child: Icon(icon, color: scheme.onSurfaceVariant)),
      ),
    );
    final p = path;
    if (p == null || p.isEmpty) return fallback(Icons.image_outlined);
    return ref
        .watch(storageUrlProvider(p))
        .when(
          data: (url) => CachedImage(url: url, fit: fit, cacheWidth: cacheWidth, borderRadius: borderRadius, width: width, height: height),
          loading: () => ClipRRect(
            borderRadius: borderRadius ?? BorderRadius.zero,
            child: ShimmerArea(
              child: ShimmerBox(width: width, height: height, borderRadius: 0),
            ),
          ),
          error: (_, _) => fallback(Icons.broken_image_outlined),
        );
  }
}
