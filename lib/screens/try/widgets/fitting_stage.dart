import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

/// Dene ekranının sahnesi: solda büyük "sen" kartı, sağda hafif eğik duran etiketli kıyafet kartı.
class FittingStage extends StatelessWidget {
  const FittingStage({
    super.key,
    required this.photoPath,
    required this.garmentPath,
    required this.garmentTitle,
    required this.onPickPhoto,
    required this.onPickGarment,
  });

  final String? photoPath;
  final String? garmentPath;
  final String? garmentTitle;
  final VoidCallback onPickPhoto;
  final VoidCallback onPickGarment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final photoW = w * 0.6;
        final garmentW = w * 0.47;
        final garmentTop = w * 0.15;
        final height = math.max(photoW * 4 / 3, garmentTop + garmentW * 4 / 3) + 10;
        return SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: 0,
                width: photoW,
                child: _Slot(
                  index: '01',
                  label: 'Sen',
                  path: photoPath,
                  emptyIcon: Icons.accessibility_new_rounded,
                  emptyText: 'Boydan\nfotoğrafını seç',
                  onTap: onPickPhoto,
                ),
              ),
              Positioned(
                right: 0,
                top: garmentTop,
                width: garmentW,
                child: Transform.rotate(
                  angle: 3.5 * math.pi / 180,
                  child: _Slot(
                    index: '02',
                    label: 'Kıyafet',
                    path: garmentPath,
                    fit: BoxFit.contain,
                    paper: true,
                    emptyIcon: Icons.checkroom_rounded,
                    emptyText: 'Denemek\nistediğin kıyafet',
                    onTap: onPickGarment,
                    tag: garmentTitle,
                  ),
                ),
              ),
              // Kesişimde kiremit "+" mührü.
              Positioned(
                left: w - garmentW - 24,
                top: garmentTop + garmentW * 2 / 3 - 22,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.terracotta,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).colorScheme.surface, width: 4),
                  ),
                  child: const Icon(Icons.add_rounded, color: AppColors.white, size: 22),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.index,
    required this.label,
    required this.path,
    required this.emptyIcon,
    required this.emptyText,
    required this.onTap,
    this.fit = BoxFit.cover,
    this.paper = false,
    this.tag,
  });

  final String index;
  final String label;
  final String? path;
  final IconData emptyIcon;
  final String emptyText;
  final VoidCallback onTap;
  final BoxFit fit;
  final bool paper;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(26);
    final empty = path == null;
    return Semantics(
      button: true,
      label: empty ? emptyText.replaceAll('\n', ' ') : '$label, değiştir',
      child: GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Container(
            decoration: BoxDecoration(
              color: empty ? AppColors.transparent : (paper ? scheme.surfaceContainerLowest : scheme.surfaceContainer),
              borderRadius: radius,
              boxShadow: empty || dark
                  ? null
                  : [BoxShadow(color: AppColors.plum950.withValues(alpha: 0.14), blurRadius: 28, offset: const Offset(0, 14))],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: empty
                  ? CustomPaint(
                      painter: _DashedBorderPainter(color: scheme.outline, radius: 26),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(color: scheme.secondaryContainer, shape: BoxShape.circle),
                                child: Icon(emptyIcon, color: scheme.secondary),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                emptyText,
                                textAlign: TextAlign.center,
                                style: AppType.serif(size: 15, weight: FontWeight.w500, color: scheme.onSurface, height: 1.2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Padding(
                          padding: paper ? const EdgeInsets.fromLTRB(12, 30, 12, 44) : EdgeInsets.zero,
                          child: StorageImage(path: path, fit: fit),
                        ),
                        if (!paper)
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.center,
                                end: Alignment.bottomCenter,
                                colors: [AppColors.transparent, AppColors.plumShade],
                              ),
                            ),
                          ),
                        if (paper && tag != null) Positioned(left: 10, right: 10, bottom: 10, child: _GarmentTag(text: tag!)),
                        Positioned(
                          right: 10,
                          top: 10,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: AppColors.white.withValues(alpha: 0.92),
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: AppColors.black.withValues(alpha: 0.12), blurRadius: 8)],
                            ),
                            child: const Icon(Icons.sync_alt_rounded, size: 16, color: AppColors.plum900),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    ).withLabel(index, label, onImage: !empty && !paper);
  }
}

extension on Widget {
  /// Kartın sol üstüne "01 · SEN" etiketi koyar.
  Widget withLabel(String index, String label, {required bool onImage}) => Builder(
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      final color = onImage ? AppColors.white : scheme.onSurfaceVariant;
      return Stack(
        children: [
          this,
          Positioned(
            left: 14,
            top: 12,
            child: IgnorePointer(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$index  ',
                      style: AppType.serif(size: 13, italic: true, color: onImage ? AppColors.white : scheme.secondary),
                    ),
                    TextSpan(text: label.toUpperCase(), style: AppType.overline(color, size: 10)),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// Kıyafet etiketi: pirinç delikli küçük kâğıt etiket üzerinde italik ad.
class _GarmentTag extends StatelessWidget {
  const _GarmentTag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.brass, width: 1.6),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.serif(size: 12.5, italic: true, weight: FontWeight.w400, color: scheme.onSurface, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius((Offset.zero & size).deflate(1), Radius.circular(radius));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 7), paint);
        d += 12;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}

/// "Yan ve arka açı" seçeneği: üç küçük siluet + anahtar.
class AngleOptionTile extends StatelessWidget {
  const AngleOptionTile({super.key, required this.value, required this.onChanged, required this.extraCost});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final int extraCost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return PaperCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Row(
        children: [
          _AngleGlyphs(active: value),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ön, yan ve arka', style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  value ? 'Üç açıdan göreceksin · +$extraCost kredi' : 'Yalnızca önden görünüm',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _AngleGlyphs extends StatelessWidget {
  const _AngleGlyphs({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget glyph(IconData icon, bool on) => AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 26,
      height: 34,
      margin: const EdgeInsets.only(right: 3),
      decoration: BoxDecoration(color: on ? scheme.secondaryContainer : scheme.surfaceContainer, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 18, color: on ? scheme.secondary : scheme.onSurfaceVariant.withValues(alpha: 0.5)),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        glyph(Icons.accessibility_new_rounded, true),
        glyph(Icons.directions_walk_rounded, active),
        glyph(Icons.person_rounded, active),
      ],
    );
  }
}
