import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Küçük durum etiketi (Hazır, İşleniyor, Uygun değil...): hap şeklinde, başında renk noktası.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, this.tone = BadgeTone.neutral, this.icon, this.onImage = false});

  final String label;
  final BadgeTone tone;
  final IconData? icon;

  /// Görsel üstünde okunaklı olsun diye yarı saydam koyu zemin.
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dot = switch (tone) {
      BadgeTone.positive => AppColors.success,
      BadgeTone.warning => AppColors.warning,
      BadgeTone.negative => scheme.error,
      BadgeTone.neutral => scheme.onSurfaceVariant,
    };
    final bg = onImage ? AppColors.black.withValues(alpha: 0.45) : scheme.surfaceContainerLowest;
    final fg = onImage ? AppColors.white : scheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(40),
        border: onImage ? null : Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 12, color: onImage ? AppColors.white : dot)
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

enum BadgeTone { positive, warning, negative, neutral }
