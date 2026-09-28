import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Kabin logosu: pirinç korniş + kadife perde + askı. Vektörel, asset gerektirmez.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 72, this.showWordmark = false, this.wordmarkColor});

  final double size;
  final bool showWordmark;
  final Color? wordmarkColor;

  @override
  Widget build(BuildContext context) {
    final mark = CustomPaint(size: Size.square(size), painter: _MarkPainter());
    if (!showWordmark) return mark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(height: size * 0.18),
        Wordmark(size: size * 0.5, color: wordmarkColor),
      ],
    );
  }
}

/// "Kabin." yazısı: serif, sonda kiremit nokta.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 36, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'Kabin'),
          TextSpan(
            text: '.',
            style: TextStyle(color: scheme.secondary),
          ),
        ],
      ),
      style: AppType.serif(size: size, weight: FontWeight.w600, color: color ?? scheme.onSurface),
    );
  }
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(w * 0.3));
    canvas.save();
    canvas.clipRRect(rrect);

    // Kadife kıvrımlar.
    const folds = 5;
    final colors = <Color>[];
    final stops = <double>[];
    for (var i = 0; i <= folds; i++) {
      final f = i / folds;
      colors
        ..add(AppColors.plum950)
        ..add(AppColors.plum700);
      stops
        ..add(f)
        ..add((f + 0.5 / folds).clamp(0, 1));
    }
    canvas.drawRect(rect, Paint()..shader = LinearGradient(colors: colors, stops: stops).createShader(rect));
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.black.withValues(alpha: 0.35), AppColors.black.withValues(alpha: 0), AppColors.black.withValues(alpha: 0.35)],
        ).createShader(rect),
    );

    // Perde aralığı: ortadan sızan ışık.
    final gap = Rect.fromCenter(center: Offset(w / 2, w * 0.6), width: w * 0.36, height: w * 1.1);
    canvas.drawRect(
      gap,
      Paint()
        ..shader = RadialGradient(colors: [AppColors.blush.withValues(alpha: 0.5), AppColors.blush.withValues(alpha: 0)]).createShader(gap),
    );

    // Pirinç korniş.
    canvas.drawRect(Rect.fromLTWH(0, w * 0.16, w, w * 0.05), Paint()..color = AppColors.brass);

    // Askı.
    final hanger = Paint()
      ..color = AppColors.ivory
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.055
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final cx = w / 2;
    final path = Path()
      ..moveTo(cx - w * 0.045, w * 0.33)
      ..quadraticBezierTo(cx - w * 0.045, w * 0.24, cx + w * 0.02, w * 0.25)
      ..quadraticBezierTo(cx + w * 0.08, w * 0.28, cx, w * 0.4)
      ..lineTo(cx - w * 0.24, w * 0.6)
      ..lineTo(cx + w * 0.24, w * 0.6)
      ..close();
    canvas.drawPath(path, hanger);

    // Kiremit nokta.
    canvas.drawCircle(Offset(cx, w * 0.77), w * 0.055, Paint()..color = AppColors.terracotta);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter old) => false;
}
