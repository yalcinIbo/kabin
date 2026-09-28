import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';

/// Açılış: kapalı kadife perde, ortada logo.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.plum950,
    body: Stack(
      fit: StackFit.expand,
      children: [
        const SwayingCurtain(),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(size: 76),
              const SizedBox(height: 18),
              const Wordmark(size: 44, color: AppColors.moon),
              const SizedBox(height: 6),
              Text(
                'Üstünde nasıl durur?',
                style: AppType.serif(size: 17, italic: true, weight: FontWeight.w400, color: AppColors.moon.withValues(alpha: 0.75)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
