import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../motion/ambient_motion.dart';
import '../../motion/motion_tokens.dart';
import '../../effects/shader_cache.dart';
import '../../theme/timo_colors.dart';

/// Full-bleed animated backdrop: fragment shader when available, blurred
/// light blobs otherwise. Reads [AmbientMotion] so page transitions, button
/// presses and selections steer it. A static frame is drawn under reduced
/// motion. [colors] tints the three light blobs (brand colours by default).
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({
    super.key,
    this.intensity = 1,
    this.colors = brandColors,
  });
  final double intensity;
  final List<Color> colors;
  static const brandColors = [
    Color(0xFF299E5C),
    Color(0xFF663DC7),
    Color(0xFF1A85A8),
  ];
  static const _shader = 'shaders/aurora.frag';
  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  final time = ValueNotifier<double>(0);
  Ticker? ticker;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = !Motion.reduced(context);
    if (animate && ticker == null) {
      ticker = createTicker((d) => time.value = d.inMicroseconds / 1e6)
        ..start();
    } else if (!animate) {
      ticker?.dispose();
      ticker = null;
    }
  }

  @override
  void dispose() {
    ticker?.dispose();
    time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ShaderBuilder(
      asset: AuroraBackground._shader,
      fallback: CustomPaint(
        painter: _BlobPainter(time, widget.intensity, widget.colors),
        size: Size.infinite,
      ),
      builder: (_, shader) => CustomPaint(
        painter: _AuroraPainter(shader, time, widget.intensity, widget.colors),
        size: Size.infinite,
      ),
    ),
  );
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.shader, this.time, this.intensity, this.colors)
    : super(repaint: Listenable.merge([time, AmbientMotion.instance]));
  final ui.FragmentShader shader;
  final ValueNotifier<double> time;
  final double intensity;
  final List<Color> colors;
  final _paint = Paint();
  @override
  void paint(Canvas canvas, Size size) {
    final ambient = AmbientMotion.instance;
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time.value)
      ..setFloat(3, intensity);
    for (var i = 0; i < 3; i++) {
      shader
        ..setFloat(4 + i * 3, colors[i].r)
        ..setFloat(5 + i * 3, colors[i].g)
        ..setFloat(6 + i * 3, colors[i].b);
    }
    shader
      ..setFloat(13, ambient.energy)
      ..setFloat(14, ambient.focus.dx)
      ..setFloat(15, ambient.focus.dy)
      ..setFloat(16, ambient.focusStrength)
      ..setFloat(17, ambient.glow)
      ..setFloat(18, ambient.burst);
    _paint.shader = shader;
    canvas.drawRect(Offset.zero & size, _paint);
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.shader != shader ||
      old.intensity != intensity ||
      old.colors != colors;
}

class _BlobPainter extends CustomPainter {
  _BlobPainter(this.time, this.intensity, this.colors)
    : super(repaint: Listenable.merge([time, AmbientMotion.instance]));
  final ValueNotifier<double> time;
  final double intensity;
  final List<Color> colors;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = TimoColors.background);
    final ambient = AmbientMotion.instance;
    final t = time.value * (0.55 + 0.9 * ambient.energy);
    final bright =
        intensity * (0.8 + 0.5 * ambient.energy + 0.6 * ambient.burst);
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90);
    void blob(Offset c, Color color, double r, double alpha) {
      paint.color = color.withValues(alpha: (alpha * bright).clamp(0, 1));
      canvas.drawCircle(c, r, paint);
    }

    blob(
      Offset(
        size.width * (0.18 + 0.16 * math.sin(t * 0.5)),
        size.height * (0.22 + 0.1 * math.cos(t * 0.41)),
      ),
      colors[0],
      size.width * 0.5,
      0.42,
    );
    blob(
      Offset(
        size.width * (0.86 + 0.12 * math.cos(t * 0.37)),
        size.height * (0.12 + 0.14 * math.sin(t * 0.63)),
      ),
      colors[1],
      size.width * 0.42,
      0.42,
    );
    final orbit = Offset(
      size.width * (0.62 + 0.22 * math.sin(t * 0.29 + 1)),
      size.height * (0.8 + 0.1 * math.sin(t * 0.47)),
    );
    final target = Offset(
      size.width * ambient.focus.dx,
      size.height * ambient.focus.dy,
    );
    blob(
      Offset.lerp(orbit, target, ambient.focusStrength)!,
      colors[2],
      size.width * (0.45 - 0.15 * ambient.focusStrength),
      0.42 + 0.25 * ambient.focusStrength,
    );
    if (ambient.glow > 0) {
      blob(
        Offset(size.width * 0.5, size.height * 1.05),
        colors[0],
        size.width * 0.5,
        0.5 * ambient.glow,
      );
    }
  }

  @override
  bool shouldRepaint(_BlobPainter old) =>
      old.intensity != intensity || old.colors != colors;
}
