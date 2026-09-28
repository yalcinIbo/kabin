import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/enums.dart';
import '../../../core/widgets/widgets.dart';
import '../../../models/photo/photo_model.dart';
import '../../../providers/photo/photo_providers.dart';

/// Fotoğraf kartı. İşlenmekte olan (avatar üretimi) fotoğraf canlı izlenir.
class PhotoTile extends ConsumerWidget {
  const PhotoTile({super.key, required this.photo, this.onTap, this.selected = false});

  final PhotoModel photo;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = photo.status.isBusy ? ref.watch(photoProvider(photo.id)).value ?? photo : photo;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: onTap != null,
      label: 'Fotoğraf, ${live.status.labelTr}${live.isDefault ? ', varsayılan' : ''}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: selected ? scheme.secondary : scheme.outlineVariant, width: selected ? 2.5 : 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (live.displayPath != null)
                  StorageImage(path: live.displayPath)
                else
                  ColoredBox(
                    color: scheme.surfaceContainerHigh,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                Positioned(
                  left: 8,
                  top: 8,
                  right: 8,
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      if (live.isDefault) const StatusBadge(label: 'Varsayılan', icon: Icons.star_rounded, onImage: true),
                      if (live.isGenerated) const StatusBadge(label: 'Stüdyo', icon: Icons.auto_awesome_rounded, onImage: true),
                      if (live.status != PhotoStatus.ready)
                        StatusBadge(
                          label: live.status.labelTr,
                          tone: live.status.isBusy ? BadgeTone.warning : BadgeTone.negative,
                          onImage: true,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
