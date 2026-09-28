import 'package:flutter/material.dart';

import '../../../models/photo/photo_model.dart';

/// Gemini kalite kontrolü sonucu kartı.
class QcFeedbackCard extends StatelessWidget {
  const QcFeedbackCard({super.key, required this.qc});

  final PhotoQcModel qc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final passed = qc.passed;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: passed ? scheme.primaryContainer : scheme.errorContainer, borderRadius: BorderRadius.circular(18)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            passed ? Icons.check_circle_rounded : Icons.info_rounded,
            color: passed ? scheme.onPrimaryContainer : scheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  passed ? 'Fotoğraf uygun' : (qc.blocked ? 'Bu fotoğraf kullanılamaz' : 'Tekrar çekmen gerekiyor'),
                  style: theme.textTheme.titleSmall?.copyWith(color: passed ? scheme.onPrimaryContainer : scheme.onErrorContainer),
                ),
                const SizedBox(height: 4),
                Text(
                  qc.hintTr,
                  style: theme.textTheme.bodyMedium?.copyWith(color: passed ? scheme.onPrimaryContainer : scheme.onErrorContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
