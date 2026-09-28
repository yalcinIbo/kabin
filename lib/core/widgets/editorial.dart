import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Dergi tarzı başlık: küçük üst etiket + büyük serif başlık; [accent] kelimesi italik ve vurgu renginde.
///
/// `title: 'Üstünde {nasıl} durur?'` gibi süslü parantezle işaretlenen kısım italik vurgulanır.
class EditorialHeader extends StatelessWidget {
  const EditorialHeader({
    super.key,
    required this.title,
    this.overline,
    this.subtitle,
    this.size = 38,
    this.trailing,
    this.align = CrossAxisAlignment.start,
  });

  final String title;
  final String? overline;
  final String? subtitle;
  final double size;
  final Widget? trailing;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textAlign = align == CrossAxisAlignment.center ? TextAlign.center : TextAlign.start;
    return Column(
      crossAxisAlignment: align,
      children: [
        if (overline != null || trailing != null)
          Row(
            children: [
              if (overline != null) Expanded(child: Overline(overline!)) else const Spacer(),
              ?trailing,
            ],
          ),
        if (overline != null || trailing != null) const SizedBox(height: 14),
        Text.rich(
          TextSpan(children: _spans(title, scheme)),
          textAlign: textAlign,
          style: AppType.serif(size: size, color: scheme.onSurface, weight: FontWeight.w500),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(
            subtitle!,
            textAlign: textAlign,
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  List<InlineSpan> _spans(String text, ColorScheme scheme) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'\{([^}]*)\}');
    var last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      spans.add(
        TextSpan(
          text: m.group(1),
          style: AppType.serif(size: size, italic: true, color: scheme.secondary, weight: FontWeight.w400),
        ),
      );
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }
}

/// Büyük harf, geniş aralıklı küçük etiket; başında kısa çizgi.
class Overline extends StatelessWidget {
  const Overline(this.text, {super.key, this.color, this.dash = true});

  final String text;
  final Color? color;
  final bool dash;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dash) ...[Container(width: 18, height: 1.4, color: Theme.of(context).colorScheme.secondary), const SizedBox(width: 8)],
        Flexible(
          child: Text(text.toUpperCase(), style: AppType.overline(c), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

/// Bölüm başlığı: serif başlık + isteğe bağlı sağ aksiyon.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            title,
            style: AppType.serif(size: 20, weight: FontWeight.w600, color: scheme.onSurface),
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.secondary)),
          ),
      ],
    );
  }
}

/// İnce, kâğıt dokulu kart: beyaz zemin + kıl çizgi + yumuşak gölge.
class PaperCard extends StatelessWidget {
  const PaperCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap, this.color, this.radius = 24});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final br = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerLowest,
        borderRadius: br,
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: dark ? null : [BoxShadow(color: scheme.shadow.withValues(alpha: 0.05), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: br,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
