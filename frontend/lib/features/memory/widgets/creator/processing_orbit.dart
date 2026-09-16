import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../motion/motion_tokens.dart';
import '../../theme/timo_colors.dart';

/// Processing indicator: rotating dashed orbits, orbiting sparks and a
/// breathing core. Purely decorative; the status text carries meaning.
class ProcessingOrbit extends StatefulWidget {
  const ProcessingOrbit({super.key, this.size = 180});
  final double size;
  @override
  State<ProcessingOrbit> createState() => _ProcessingOrbitState();
}

class _ProcessingOrbitState extends State<ProcessingOrbit>
    with SingleTickerProviderStateMixin {
  final time = ValueNotifier<double>(0.6);
  Ticker? ticker;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!Motion.reduced(context) && ticker == null) {
      ticker = createTicker((d) => time.value = d.inMicroseconds / 1e6)
        ..start();
    }
  }

  @override
  void dispose() {
    ticker?.dispose();
    time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '처리 중',
    child: SizedBox.square(
      dimension: widget.size,
      child: CustomPaint(painter: _OrbitPainter(time)),
    ),
  );
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter(this.time) : super(repaint: time);
  final ValueNotifier<double> time;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final t = time.value;
    final r = size.width / 2;
    final breathe = 0.5 + 0.5 * math.sin(t * 2.4);
    // Core glow.
    canvas.drawCircle(
      c,
      r * (0.28 + 0.04 * breathe),
      Paint()
        ..shader = RadialGradient(
          colors: [
            TimoColors.accentSoft.withValues(alpha: 0.9),
            TimoColors.accent.withValues(alpha: 0.35),
            TimoColors.accent.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r * 0.34)),
    );
    // Dashed orbits at different speeds and directions.
    final rings = [
      (radius: r * 0.55, speed: 0.6, dashes: 18, color: TimoColors.accent),
      (radius: r * 0.75, speed: -0.35, dashes: 30, color: TimoColors.cyan),
      (radius: r * 0.95, speed: 0.22, dashes: 46, color: TimoColors.violet),
    ];
    for (final ring in rings) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = ring.color.withValues(alpha: 0.55);
      final rect = Rect.fromCircle(center: c, radius: ring.radius);
      final gap = math.pi * 2 / ring.dashes;
      for (var i = 0; i < ring.dashes; i++) {
        final start = t * ring.speed + i * gap;
        canvas.drawArc(rect, start, gap * 0.45, false, paint);
      }
      // Bright spark travelling the orbit.
      final a = t * ring.speed * 3.0;
      final spark = c + Offset(math.cos(a), math.sin(a)) * ring.radius;
      canvas.drawCircle(
        spark,
        3,
        Paint()
          ..color = Colors.white
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(spark, 1.8, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => false;
}
