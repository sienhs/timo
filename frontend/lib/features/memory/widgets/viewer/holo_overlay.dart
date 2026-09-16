import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../effects/shader_cache.dart';
import '../../theme/timo_colors.dart';
import '../../constants.dart';

/// Additive holographic foil sheen that follows the card tilt. Intensity
/// eases from [idle] to [active] as the tilt grows. Repaints via listenables.
class HoloOverlay extends StatelessWidget {
  const HoloOverlay({
    super.key,
    required this.tilt,
    required this.time,
    required this.idle,
    required this.active,
  });
  final ValueListenable<Offset> tilt;
  final ValueListenable<double> time;
  final double idle, active;
  static const _shader = 'shaders/holo_foil.frag';
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: ShaderBuilder(
        asset: _shader,
        fallback: CustomPaint(
          painter: _SheenPainter(tilt, idle, active),
          size: Size.infinite,
        ),
        builder: (_, shader) => CustomPaint(
          painter: _HoloPainter(shader, tilt, time, idle, active),
          size: Size.infinite,
        ),
      ),
    ),
  );
}

double _intensity(Offset tilt, double idle, double active) {
  final activity = math.min(1.0, tilt.distance / ViewerConstants.maxTilt);
  return idle + (active - idle) * activity;
}

class _HoloPainter extends CustomPainter {
  _HoloPainter(this.shader, this.tilt, this.time, this.idle, this.active)
    : super(repaint: Listenable.merge([tilt, time]));
  final ui.FragmentShader shader;
  final ValueListenable<Offset> tilt;
  final ValueListenable<double> time;
  final double idle, active;
  final _paint = Paint()..blendMode = BlendMode.plus;
  @override
  void paint(Canvas canvas, Size size) {
    final n = tilt.value / ViewerConstants.maxTilt;
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, n.dx)
      ..setFloat(3, n.dy)
      ..setFloat(4, time.value)
      ..setFloat(5, _intensity(tilt.value, idle, active));
    _paint.shader = shader;
    canvas.drawRect(Offset.zero & size, _paint);
  }

  @override
  bool shouldRepaint(_HoloPainter old) =>
      old.shader != shader || old.idle != idle || old.active != active;
}

/// Gradient approximation for devices without fragment shader support.
class _SheenPainter extends CustomPainter {
  _SheenPainter(this.tilt, this.idle, this.active) : super(repaint: tilt);
  final ValueListenable<Offset> tilt;
  final double idle, active;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final n = tilt.value / ViewerConstants.maxTilt;
    final intensity = _intensity(tilt.value, idle, active);
    final pos = (0.62 + n.dx * 0.4 - n.dy * 0.25).clamp(0.1, 0.9);
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.transparent,
            TimoColors.cyan.withValues(alpha: 0.35 * intensity),
            Colors.white.withValues(alpha: 0.5 * intensity),
            TimoColors.magenta.withValues(alpha: 0.35 * intensity),
            Colors.transparent,
          ],
          stops: [
            (pos - 0.28).clamp(0, 1),
            (pos - 0.1).clamp(0, 1),
            pos,
            (pos + 0.1).clamp(0, 1),
            (pos + 0.28).clamp(0, 1),
          ],
        ).createShader(rect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(0.75),
        const Radius.circular(TimoRadii.card),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..blendMode = BlendMode.plus
        ..shader = SweepGradient(
          transform: GradientRotation(n.dx * 1.2),
          colors: [
            TimoColors.accent.withValues(alpha: 0.6 * intensity),
            TimoColors.violet.withValues(alpha: 0.2 * intensity),
            TimoColors.cyan.withValues(alpha: 0.6 * intensity),
            TimoColors.accent.withValues(alpha: 0.6 * intensity),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SheenPainter old) =>
      old.tilt != tilt || old.idle != idle || old.active != active;
}
