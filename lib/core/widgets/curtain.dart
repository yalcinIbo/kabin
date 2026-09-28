import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Kabin perdesi: iki kadife panel + pirinç korniş. [open] 0 = kapalı, 1 = iki yana toplanmış.
/// [sway] -1..1 arası hafif salınım (bekleme animasyonu).
class CurtainPainter extends CustomPainter {
  CurtainPainter({required this.open, this.sway = 0, this.glow = 0, this.fade = 1});

  final double open;
  final double sway;

  /// Perde aralığından sızan ışık (0..1).
  final double glow;

  /// Tüm perdenin görünürlüğü (açıldıktan sonra kaybolması için).
  final double fade;

  @override
  void paint(Canvas canvas, Size size) {
    if (fade <= 0) return;
    final w = size.width;
    final h = size.height;
    final t = Curves.easeInOutCubic.transform(open.clamp(0, 1));
    final panelW = lerpDouble(w / 2 + 1, w * 0.11, t)!;

    canvas.saveLayer(Offset.zero & size, Paint()..color = AppColors.white.withValues(alpha: fade.clamp(0, 1)));

    if (glow > 0 && t < 0.98) {
      // Kapalı perdenin ortasından sızan sıcak ışık.
      final glowRect = Rect.fromCenter(center: Offset(w / 2, h * 0.55), width: w * 0.22, height: h * 1.1);
      canvas.drawRect(
        glowRect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              AppColors.blush.withValues(alpha: 0.55 * glow),
              AppColors.blush.withValues(alpha: 0),
            ],
          ).createShader(glowRect),
      );
    }

    _panel(canvas, size, panelW, t, left: true);
    _panel(canvas, size, panelW, t, left: false);
    _rod(canvas, size);
    canvas.restore();
  }

  void _panel(Canvas canvas, Size size, double panelW, double t, {required bool left}) {
    final h = size.height;
    final w = size.width;
    final outer = left ? 0.0 : w;
    final inner = left ? panelW : w - panelW;
    final dir = left ? 1.0 : -1.0;

    // İç kenar: toplandıkça ortası dışarı doğru bükülür (bağlanmış perde); salınımda hafifçe dalgalanır.
    final bow = panelW * 0.28 * t;
    final swayX = sway * 6 * (1 - t);
    final path = Path()
      ..moveTo(outer, 0)
      ..lineTo(inner, 0)
      ..cubicTo(
        inner - dir * bow + swayX,
        h * 0.35,
        inner - dir * bow * 1.4 - swayX,
        h * 0.62,
        inner + dir * panelW * 0.06 * t + swayX * 0.5,
        h,
      )
      ..lineTo(outer, h)
      ..close();

    final folds = (6 + 4 * t).round();
    final colors = <Color>[];
    final stops = <double>[];
    for (var i = 0; i <= folds; i++) {
      final f = i / folds;
      colors
        ..add(AppColors.plum950)
        ..add(Color.lerp(AppColors.plum700, AppColors.plum500, 0.25)!);
      stops
        ..add(f)
        ..add((f + 0.5 / folds).clamp(0, 1));
    }
    final bounds = Rect.fromLTRB(math.min(outer, inner) - 20, 0, math.max(outer, inner) + 20, h);
    final shift = sway * 0.03;
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(-1 + shift, 0),
          end: Alignment(1 + shift, 0),
          colors: colors.take(stops.length).toList(),
          stops: stops,
        ).createShader(bounds),
    );
    // Dikey gölge: üst ve alt koyu, orta daha parlak (kadife derinliği).
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.black.withValues(alpha: 0.35),
            AppColors.black.withValues(alpha: 0),
            AppColors.black.withValues(alpha: 0.05),
            AppColors.black.withValues(alpha: 0.4),
          ],
          stops: const [0, 0.18, 0.7, 1],
        ).createShader(bounds),
    );
    // İç kenarda ince parlak hat.
    canvas.drawPath(
      Path()
        ..moveTo(inner, 0)
        ..cubicTo(
          inner - dir * bow + swayX,
          h * 0.35,
          inner - dir * bow * 1.4 - swayX,
          h * 0.62,
          inner + dir * panelW * 0.06 * t + swayX * 0.5,
          h,
        ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.plum300.withValues(alpha: 0.35),
    );
  }

  void _rod(Canvas canvas, Size size) {
    final w = size.width;
    final rod = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.brassLight, AppColors.brass, AppColors.brassDark],
      ).createShader(Rect.fromLTWH(0, 0, w, 7));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, 6), const Radius.circular(3)), rod);
  }

  @override
  bool shouldRepaint(CurtainPainter old) => old.open != open || old.sway != sway || old.glow != glow || old.fade != fade;
}

/// Çocuğunu perde açılarak gösterir. [animate] false ise perde hiç çizilmez.
class CurtainReveal extends StatefulWidget {
  const CurtainReveal({super.key, required this.child, this.animate = true, this.duration = const Duration(milliseconds: 1500)});

  final Widget child;
  final bool animate;
  final Duration duration;

  @override
  State<CurtainReveal> createState() => _CurtainRevealState();
}

class _CurtainRevealState extends State<CurtainReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _c.forward();
      });
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final scale = lerpDouble(1.04, 1, Curves.easeOut.transform(_c.value))!;
            return Transform.scale(scale: scale, child: child);
          },
          child: widget.child,
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                if (_c.value >= 1) return const SizedBox.shrink();
                final v = _c.value;
                final fade = v < 0.75 ? 1.0 : 1 - (v - 0.75) / 0.25;
                return CustomPaint(
                  painter: CurtainPainter(open: math.min(1, v / 0.8), fade: fade),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Kapalı, hafifçe salınan perde; arkasında ışık sızar. Bekleme ekranı için.
class SwayingCurtain extends StatefulWidget {
  const SwayingCurtain({super.key, this.child});

  /// Perdenin arkasında (bulanık) duran içerik.
  final Widget? child;

  @override
  State<SwayingCurtain> createState() => _SwayingCurtainState();
}

class _SwayingCurtainState extends State<SwayingCurtain> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.child != null) widget.child!,
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final phase = _c.value * 2 * math.pi;
            return CustomPaint(
              painter: CurtainPainter(
                open: 0.04 + 0.03 * (math.sin(phase) + 1) / 2,
                sway: math.sin(phase),
                glow: 0.6 + 0.4 * (math.sin(phase * 2) + 1) / 2,
              ),
            );
          },
        ),
      ],
    );
  }
}
