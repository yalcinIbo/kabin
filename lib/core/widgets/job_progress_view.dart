import 'package:flutter/material.dart';

import '../enums/enums.dart';

/// Sunucu işinin canlı ilerlemesi (aşama etiketi + çubuk).
class JobProgressView extends StatelessWidget {
  const JobProgressView({super.key, required this.status, this.stage, this.progress = 0, this.hint});

  final JobStatus status;
  final JobStage? stage;
  final double progress;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = status == JobStatus.queued ? 'Sıraya alındı' : (stage?.labelTr ?? status.labelTr);
    final value = status == JobStatus.queued ? null : progress.clamp(0.05, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(value: value, strokeWidth: 5, backgroundColor: theme.colorScheme.primaryContainer),
              ),
              Icon(Icons.checkroom_rounded, size: 30, color: theme.colorScheme.primary),
            ],
          ),
        ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(label, key: ValueKey(label), style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
        ),
        const SizedBox(height: 6),
        Text(
          hint ?? 'Bu işlem genellikle 20-60 saniye sürer. Ekrandan çıkabilirsin; sonuç Geçmiş\'e düşer.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
