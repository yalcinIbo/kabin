import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/enums/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../models/tryon/tryon_job_model.dart';

/// Deneme sürerken: perde kapalı ve salınıyor, arkasında bulanık fotoğrafın; altında adım adım ilerleme.
class FittingProgress extends StatefulWidget {
  const FittingProgress({super.key, required this.job});

  final TryOnJobModel job;

  @override
  State<FittingProgress> createState() => _FittingProgressState();
}

class _FittingProgressState extends State<FittingProgress> {
  late final DateTime _start = widget.job.createdAt ?? DateTime.now();
  late final Timer _timer = Timer.periodic(const Duration(seconds: 1), (_) {
    if (mounted) setState(() {});
  });

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  List<(JobStage, String)> get _steps => [
    (JobStage.tryon, 'Kıyafet üzerine giydiriliyor'),
    if (widget.job.multiView) (JobStage.multiview, 'Yan ve arka açılar çekiliyor'),
    (JobStage.advice, 'Stil notların yazılıyor'),
    (JobStage.saving, 'Son rötuşlar'),
  ];

  int get _activeIndex {
    final stage = widget.job.stage;
    final i = _steps.indexWhere((s) => s.$1 == stage);
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final elapsed = DateTime.now().difference(_start);
    final secs = elapsed.inSeconds.clamp(0, 5999);
    final clock = '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';
    final queued = widget.job.status == JobStatus.queued;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: SwayingCurtain(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: StorageImage(path: widget.job.photoThumbPath),
                      ),
                      ColoredBox(color: AppColors.plum950.withValues(alpha: 0.35)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(30)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _Pulse(),
                const SizedBox(width: 8),
                Text('KABİN DOLU', style: AppType.overline(scheme.onPrimary, size: 10)),
                const SizedBox(width: 10),
                Text(clock, style: AppType.numeric(size: 12, color: scheme.onPrimary)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 26),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Perdenin arkasında\n'),
              TextSpan(
                text: queued ? 'sıran geliyor…' : 'hazırlanıyorsun…',
                style: AppType.serif(size: 28, italic: true, weight: FontWeight.w400, color: scheme.secondary),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: AppType.serif(size: 28, color: scheme.onSurface),
        ),
        const SizedBox(height: 24),
        PaperCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Column(
            children: [
              for (var i = 0; i < _steps.length; i++)
                _StepRow(
                  number: i + 1,
                  label: _steps[i].$2,
                  state: queued
                      ? _StepState.pending
                      : (i < _activeIndex ? _StepState.done : (i == _activeIndex ? _StepState.active : _StepState.pending)),
                  last: i == _steps.length - 1,
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Genelde 20-60 saniye sürer. Ekrandan çıkabilirsin; sonuç Geçmiş\'te seni bekler.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

enum _StepState { done, active, pending }

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.label, required this.state, required this.last});

  final int number;
  final String label;
  final _StepState state;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = switch (state) {
      _StepState.done => scheme.onSurfaceVariant,
      _StepState.active => scheme.onSurface,
      _StepState.pending => scheme.onSurfaceVariant.withValues(alpha: 0.55),
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              number.toString().padLeft(2, '0'),
              style: AppType.serif(size: 15, italic: true, color: state == _StepState.pending ? color : scheme.secondary),
            ),
          ),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: state == _StepState.active ? FontWeight.w800 : FontWeight.w500,
                decoration: state == _StepState.done ? TextDecoration.lineThrough : null,
                decorationColor: scheme.outline,
              ),
            ),
          ),
          SizedBox(
            width: 22,
            height: 22,
            child: switch (state) {
              _StepState.done => Icon(Icons.check_circle_rounded, size: 20, color: scheme.secondary),
              _StepState.active => CircularProgressIndicator(strokeWidth: 2.2, color: scheme.secondary),
              _StepState.pending => Icon(Icons.circle_outlined, size: 18, color: scheme.outline),
            },
          ),
        ],
      ),
    );
  }
}

/// Yanıp sönen kiremit nokta.
class _Pulse extends StatefulWidget {
  const _Pulse();

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
    child: Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(color: AppColors.terracotta, shape: BoxShape.circle),
    ),
  );
}
