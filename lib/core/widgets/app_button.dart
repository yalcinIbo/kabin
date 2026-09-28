import 'package:flutter/material.dart';

enum AppButtonVariant { primary, accent, secondary, outline, text, danger }

/// Hap şeklinde standart buton; yükleniyor durumunu kendisi yönetir.
/// [primary] koyu mürdüm, [accent] kiremit (ana eylem vurgusu), [secondary] yumuşak zemin.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.trailingIcon,
    this.expanded = true,
    this.height,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonVariant variant;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool expanded;
  final double? height;

  bool get _isBig => variant == AppButtonVariant.primary || variant == AppButtonVariant.accent || variant == AppButtonVariant.danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null && !isLoading;
    final h = height ?? (_isBig ? 56.0 : 50.0);
    final size = Size(expanded ? double.infinity : 0, h);

    final (Color? bg, Color? fg) = switch (variant) {
      AppButtonVariant.primary => (scheme.primary, scheme.onPrimary),
      AppButtonVariant.accent => (scheme.secondary, scheme.onSecondary),
      AppButtonVariant.danger => (scheme.error, scheme.onError),
      AppButtonVariant.secondary => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      _ => (null, null),
    };

    final child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            // Yüklenirken buton devre dışı (açık) görünür; döndürücü bu zeminde okunur olmalı.
            child: CircularProgressIndicator(strokeWidth: 2.2, color: scheme.secondary),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: 19), const SizedBox(width: 10)],
              Flexible(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
              ),
              if (trailingIcon != null) ...[const SizedBox(width: 10), Icon(trailingIcon, size: 19)],
            ],
          );

    return switch (variant) {
      AppButtonVariant.primary || AppButtonVariant.accent || AppButtonVariant.danger || AppButtonVariant.secondary => ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(backgroundColor: bg, foregroundColor: fg, minimumSize: size),
        child: child,
      ),
      AppButtonVariant.outline => OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(minimumSize: size),
        child: child,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: enabled ? onPressed : null,
        style: TextButton.styleFrom(minimumSize: size),
        child: child,
      ),
    };
  }
}
