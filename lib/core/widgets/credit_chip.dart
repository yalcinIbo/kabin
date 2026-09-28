import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/user/user_providers.dart';
import '../router/route_names.dart';
import '../theme/app_theme.dart';

/// Kredi bakiyesi rozeti; dokununca kredi ekranı açılır. Bakiye değişince sayı yumuşakça sayar.
class CreditChip extends ConsumerWidget {
  const CreditChip({super.key, this.padRight = true});

  final bool padRight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credits = ref.watch(creditsProvider);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(right: padRight ? 16 : 0),
      child: Semantics(
        button: true,
        label: 'Kredi bakiyesi $credits',
        child: Material(
          color: scheme.surfaceContainerLowest,
          shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => context.push(RouteNames.credits),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(color: scheme.secondary, shape: BoxShape.circle),
                    child: Icon(Icons.auto_awesome_rounded, size: 14, color: scheme.onSecondary),
                  ),
                  const SizedBox(width: 8),
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: credits.toDouble()),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => Text(
                      '${v.round()}',
                      style: AppType.numeric(size: 14, weight: FontWeight.w800, color: scheme.onSurface),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
