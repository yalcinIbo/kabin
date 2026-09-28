import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Tema renkleriyle uyumlu, hafif parıltı animasyonu.
class ShimmerArea extends StatefulWidget {
  const ShimmerArea({super.key, required this.child});

  final Widget child;

  @override
  State<ShimmerArea> createState() => _ShimmerAreaState();
}

class _ShimmerAreaState extends State<ShimmerArea> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHigh;
    final highlight = scheme.surfaceContainerLowest;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [base, highlight, base],
          stops: const [0.1, 0.5, 0.9],
          transform: _Slide(_controller.value),
        ).createShader(bounds),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _Slide extends GradientTransform {
  const _Slide(this.percent);
  final double percent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) => Matrix4.translationValues(bounds.width * (percent * 2 - 1), 0, 0);
}

class ShimmerBox extends StatelessWidget {
  const ShimmerBox({super.key, this.width, this.height, this.borderRadius = 12});

  final double? width;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(borderRadius)),
  );
}

class GridSkeleton extends StatelessWidget {
  const GridSkeleton({super.key, this.aspectRatio = 0.75, this.count = 6});

  final double aspectRatio;
  final int count;

  @override
  Widget build(BuildContext context) => ShimmerArea(
    child: GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: aspectRatio,
      ),
      itemCount: count,
      itemBuilder: (_, _) => const ShimmerBox(),
    ),
  );
}

class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) => ShimmerArea(
    child: ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => const Row(
        children: [
          ShimmerBox(width: 64, height: 84),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 160, height: 14, borderRadius: 4),
                SizedBox(height: 8),
                ShimmerBox(width: 100, height: 12, borderRadius: 4),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
