import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

/// Auth ekranları için ortak düzen: üstte yarı açık kadife perde ve logo, altta kâğıt zeminde form.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, this.subtitle, required this.children, this.showLogo = true, this.appBar = false});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  /// true: büyük perde başlığı; false: daha kısa perde (kayıt gibi uzun formlar).
  final bool showLogo;

  /// Geri düğmesi gösterilsin mi.
  final bool appBar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final top = MediaQuery.paddingOf(context).top;
    final headerH = (showLogo ? 300.0 : 200.0) + top;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: headerH,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.plum800, AppColors.plum950],
                      ),
                    ),
                  ),
                  CustomPaint(painter: CurtainPainter(open: 0.66, glow: 1)),
                  Padding(
                    padding: EdgeInsets.only(top: top + 8, bottom: 36),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (showLogo) ...[const AppLogo(size: 58), const SizedBox(height: 14)],
                        const Wordmark(size: 40, color: AppColors.moon),
                        const SizedBox(height: 6),
                        Text(
                          'Üstünde nasıl durur?',
                          style: AppType.serif(
                            size: 17,
                            italic: true,
                            weight: FontWeight.w400,
                            color: AppColors.moon.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (appBar && Navigator.of(context).canPop())
                    Positioned(
                      left: 8,
                      top: top + 4,
                      child: IconButton(
                        tooltip: 'Geri',
                        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.moon),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -28),
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
                child: SafeArea(
                  top: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            EditorialHeader(title: title, size: 30, subtitle: subtitle),
                            const SizedBox(height: 22),
                            ...children,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "veya" ayırıcısı.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('veya', style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}
