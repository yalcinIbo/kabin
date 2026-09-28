import 'package:flutter/material.dart';

import '../../core/widgets/widgets.dart';

/// Sekme ekranlarının ortak iskeleti: üst etiket + kredi rozeti, büyük serif başlık, altında içerik.
class TabPage extends StatelessWidget {
  const TabPage({
    super.key,
    required this.overline,
    required this.title,
    required this.child,
    this.trailing,
    this.below,
    this.showCredits = true,
  });

  final String overline;

  /// `{...}` içindeki kısım italik vurgu olur.
  final String title;
  final Widget child;

  /// Başlık satırının sağında (ör. "Ekle" düğmesi).
  final Widget? trailing;

  /// Başlığın altında, içerikten önce (ör. bölüm seçici).
  final Widget? below;
  final bool showCredits;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                children: [
                  Expanded(child: Overline(overline)),
                  if (showCredits) const CreditChip(padRight: false),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: EditorialHeader(title: title, size: 36)),
                  ?trailing,
                ],
              ),
            ),
            if (below != null) Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 0), child: below),
            const SizedBox(height: 6),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// Hap şeklinde iki-üç seçenekli bölüm seçici; seçili olanın altında kayan koyu zemin.
class PillSegments extends StatelessWidget {
  const PillSegments({super.key, required this.labels, required this.index, required this.onChanged});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme.labelLarge;
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(30)),
      child: LayoutBuilder(
        builder: (context, c) {
          final segW = c.maxWidth / labels.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                left: segW * index,
                width: segW,
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(26)),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(i),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 250),
                            style: text!.copyWith(color: i == index ? scheme.onPrimary : scheme.onSurfaceVariant),
                            child: Text(labels[i]),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
