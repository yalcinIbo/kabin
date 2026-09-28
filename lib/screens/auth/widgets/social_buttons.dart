import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/app_button.dart';

/// Google ve (iOS'ta) Apple ile giriş düğmeleri.
class SocialButtons extends StatelessWidget {
  const SocialButtons({super.key, required this.onGoogle, required this.onApple, this.enabled = true});

  final VoidCallback onGoogle;
  final VoidCallback onApple;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final showApple = !kIsWeb && Platform.isIOS;
    return Column(
      children: [
        AppButton(
          label: 'Google ile devam et',
          icon: Icons.g_mobiledata_rounded,
          variant: AppButtonVariant.outline,
          onPressed: enabled ? onGoogle : null,
        ),
        if (showApple) ...[
          const SizedBox(height: 10),
          AppButton(
            label: 'Apple ile devam et',
            icon: Icons.apple_rounded,
            variant: AppButtonVariant.outline,
            onPressed: enabled ? onApple : null,
          ),
        ],
      ],
    );
  }
}
