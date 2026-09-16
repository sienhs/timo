import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../motion/motion_tokens.dart';
import '../../theme/timo_colors.dart';

/// The wrapped gift on the "제작중" stage. While working it breathes and
/// rocks gently with sparkles drifting up; when [celebrate] turns on the lid
/// lifts, light spills out and confetti bursts. Pure decoration.
class GiftBox extends StatefulWidget {
  const GiftBox({super.key, this.size = 200, this.celebrate = false});
  final double size;
  final bool celebrate;
  @override
  State<GiftBox> createState() => _GiftBoxState();
}

class _GiftBoxState extends State<GiftBox> with TickerProviderStateMixin {
  final time = ValueNotifier<double>(0.8);
  late final AnimationController open = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  Ticker? ticker;

  @override
  void initState() {
    super.initState();
    if (widget.celebrate) open.value = 1;
  }

  @override
  void didUpdateWidget(GiftBox old) {
    super.didUpdateWidget(old);
    if (widget.celebrate && !old.celebrate) {
      Motion.reduced(context) ? open.value = 1 : open.forward();
    }
  }

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
    open.dispose();
    time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: Size.square(widget.size),
      painter: _GiftPainter(
        time,
        CurvedAnimation(parent: open, curve: Motion.overshoot),
      ),
    ),
  );
}

class _GiftPainter extends CustomPainter {
  _GiftPainter(this.time, this.open)
    : super(repaint: Listenable.merge([time, open]));
  final ValueNotifier<double> time;
  final Animation<double> open;

  static const body = Color(0xFFD64545);
  static const bodyDark = Color(0xFFB13232);
  static const ribbon = Color(0xFFE8B84A);
  static const ribbonDark = Color(0xFFC9962B);

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final o = open.value.clamp(0.0, 1.0);
    final w = size.width, h = size.height;
    final c = Offset(w / 2, h * 0.58);
    // Idle life: a slow breath and a rock that fades once the lid is off.
    final breath = 1 + 0.02 * math.sin(t * 2.2) * (1 - o);
    final rock = 0.04 * math.sin(t * 1.7) * (1 - o);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rock);
    canvas.scale(breath);
    canvas.translate(-c.dx, -c.dy);

    // Ground shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx, h * 0.86),
        width: w * 0.62,
        height: h * 0.07,
      ),
      Paint()
        ..color = TimoColors.ink.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    final boxW = w * 0.5, boxH = h * 0.4;
    final box = Rect.fromCenter(
      center: Offset(c.dx, h * 0.64),
      width: boxW,
      height: boxH,
    );
    final r = const Radius.circular(8);

    // Glow escaping when opened.
    if (o > 0) {
      canvas.drawCircle(
        Offset(c.dx, box.top),
        boxW * 0.9 * o,
        Paint()
          ..shader =
              RadialGradient(
                colors: [
                  TimoColors.gold.withValues(alpha: 0.55 * o),
                  TimoColors.gold.withValues(alpha: 0),
                ],
              ).createShader(
                Rect.fromCircle(
                  center: Offset(c.dx, box.top),
                  radius: boxW * 0.9,
                ),
              ),
      );
    }

    // Box body with a side shade.
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, r),
      Paint()
        ..shader = const LinearGradient(
          colors: [body, bodyDark],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: [0.55, 1],
        ).createShader(box),
    );
    // Vertical ribbon on the body.
    canvas.drawRect(
      Rect.fromCenter(center: box.center, width: boxW * 0.16, height: boxH),
      Paint()..color = ribbon,
    );

    // Lid: sits on the box, lifts + tilts when celebrating.
    final lidW = boxW * 1.12, lidH = boxH * 0.24;
    final lift = o * h * 0.22, tilt = -o * 0.35;
    final lidC = Offset(c.dx + o * w * 0.12, box.top - lidH / 2 - lift);
    canvas.save();
    canvas.translate(lidC.dx, lidC.dy);
    canvas.rotate(tilt);
    final lid = Rect.fromCenter(center: Offset.zero, width: lidW, height: lidH);
    canvas.drawRRect(RRect.fromRectAndRadius(lid, r), Paint()..color = body);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: boxW * 0.16, height: lidH),
      Paint()..color = ribbon,
    );
    // Bow: two loops, two tails, a knot.
    final knot = Offset(0, -lidH / 2);
    final loopPaint = Paint()..color = ribbon;
    final loopDark = Paint()..color = ribbonDark;
    for (final dir in [-1.0, 1.0]) {
      final loop = Rect.fromCenter(
        center: knot + Offset(dir * lidW * 0.13, -lidH * 0.55),
        width: lidW * 0.26,
        height: lidH * 1.2,
      );
      canvas.drawOval(loop, loopPaint);
      canvas.drawOval(loop.deflate(lidW * 0.05), loopDark);
      canvas.drawOval(loop.deflate(lidW * 0.08), loopPaint);
      final tail = Path()
        ..moveTo(knot.dx, knot.dy)
        ..lineTo(knot.dx + dir * lidW * 0.16, knot.dy + lidH * 1.1)
        ..lineTo(knot.dx + dir * lidW * 0.06, knot.dy + lidH * 1.0)
        ..close();
      canvas.drawPath(tail, loopDark);
    }
    canvas.drawCircle(knot, lidH * 0.28, loopDark);
    canvas.restore();

    canvas.restore();

    // Sparkles: drifting up while working, bursting outward when opened.
    final rnd = math.Random(7);
    final n = 14;
    for (var i = 0; i < n; i++) {
      final seed = rnd.nextDouble();
      final phase = (t * (0.25 + seed * 0.2) + seed) % 1;
      final Offset p;
      final double alpha;
      if (o > 0) {
        final ang = seed * math.pi * 2;
        final dist = (0.2 + 0.6 * ((o + seed * 0.3) % 1)) * w * 0.55;
        p = Offset(
          c.dx + math.cos(ang) * dist,
          box.top - math.sin(ang).abs() * dist * 0.9,
        );
        alpha = (1 - phase) * o;
      } else {
        p = Offset(
          c.dx + (seed - 0.5) * w * 0.8 + math.sin(t + seed * 6) * 6,
          h * (0.9 - phase * 0.8),
        );
        alpha = math.sin(phase * math.pi) * 0.9;
      }
      final color = (i.isEven ? TimoColors.gold : TimoColors.brandMid)
          .withValues(alpha: alpha);
      final s = 2.0 + seed * 3;
      final star = Path()
        ..moveTo(p.dx, p.dy - s)
        ..lineTo(p.dx + s * 0.35, p.dy)
        ..lineTo(p.dx, p.dy + s)
        ..lineTo(p.dx - s * 0.35, p.dy)
        ..close();
      canvas.drawPath(star, Paint()..color = color);
      canvas.drawCircle(p, s * 0.25, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_GiftPainter old) => old.time != time || old.open != open;
}
