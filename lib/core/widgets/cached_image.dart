import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import 'shimmer_view.dart';

/// Disk + bellek önbellekli ağ görseli. [cacheWidth] ile decode boyutu sınırlanır.
class CachedImage extends StatelessWidget {
  const CachedImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.cacheWidth = AppConstants.gridCacheWidth,
    this.borderRadius,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final placeholder = ShimmerArea(
      child: ShimmerBox(width: width, height: height, borderRadius: 0),
    );
    Widget image = CachedNetworkImage(
      imageUrl: url,
      // Firebase indirme URL'lerindeki token değişse de aynı dosya önbellekten okunur.
      cacheKey: Uri.tryParse(url)?.replace(queryParameters: const {}).toString(),
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: cacheWidth,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: Center(child: Icon(Icons.broken_image_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ),
    );
    if (borderRadius != null) image = ClipRRect(borderRadius: borderRadius!, child: image);
    return image;
  }
}
