import 'package:flutter/material.dart';

import '../../../core/enums/enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../models/garment/garment_model.dart';

/// Kıyafet kartı: kâğıt zemin üstünde kıyafet, altında renk noktası + serif ad.
class GarmentTile extends StatelessWidget {
  const GarmentTile({super.key, required this.garment, this.onTap, this.selected = false, this.dimUnsupported = false});

  final GarmentModel garment;
  final VoidCallback? onTap;
  final bool selected;
  final bool dimUnsupported;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final analysis = garment.analysis;
    final unsupported = garment.isReady && !garment.canTryOn;
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: '${garment.title}${unsupported ? ', denenemez' : ''}',
      child: Opacity(
        opacity: dimUnsupported && !garment.canTryOn ? 0.45 : 1,
        child: GestureDetector(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: selected ? scheme.secondary : scheme.outlineVariant, width: selected ? 2.5 : 1),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: StorageImage(path: garment.displayPath, fit: BoxFit.contain),
                      ),
                      if (garment.status != GarmentStatus.ready || unsupported)
                        Positioned(
                          left: 8,
                          top: 8,
                          child: StatusBadge(
                            label: switch (garment.status) {
                              GarmentStatus.analyzing => 'Analiz ediliyor',
                              GarmentStatus.failed => 'Algılanamadı',
                              GarmentStatus.ready => 'Denenemez',
                            },
                            tone: garment.status == GarmentStatus.analyzing ? BadgeTone.warning : BadgeTone.negative,
                          ),
                        ),
                      if (selected)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: scheme.secondary,
                            child: Icon(Icons.check_rounded, size: 15, color: scheme.onSecondary),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (analysis != null) ...[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: analysis.color,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.outline),
                      ),
                    ),
                    const SizedBox(width: 7),
                  ],
                  Expanded(
                    child: Text(
                      garment.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.serif(size: 15, weight: FontWeight.w600, color: scheme.onSurface, height: 1.2),
                    ),
                  ),
                ],
              ),
              if (analysis != null && analysis.colorNameTr.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    '${analysis.category.labelTr} · ${analysis.colorNameTr}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
