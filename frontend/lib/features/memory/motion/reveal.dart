import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../effects/effect_quality.dart';
import 'motion_tokens.dart';

/// Entrance: opacity + slide-up + a short de-blur. Give siblings increasing
/// [index] for a stagger cascade. The blur filter exists only while the
/// animation runs (and never on the low quality tier), so a settled screen
/// costs nothing. Honors reduced motion by showing instantly.
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.delay = Duration.zero,
    this.duration = Motion.entrance,
    this.offset = Motion.revealOffset,
    this.scaleFrom = 1,
    this.blur = true,
  });
  final Widget child;
  final int index;
  final Duration delay;
  final Duration duration;
  final double offset;
  final double scaleFrom;
  final bool blur;
  static const maxBlurSigma = 6.0;
  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> curve = CurvedAnimation(
    parent: controller,
    curve: Motion.emphasized,
  );
  Timer? timer;
  @override
  void initState() {
    super.initState();
    final wait = widget.delay + Motion.stagger * widget.index;
    timer = Timer(wait, () {
      if (mounted) controller.forward();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return widget.child;
    final allowBlur =
        widget.blur &&
        EffectQualityController.instance.value != EffectQuality.low;
    return AnimatedBuilder(
      animation: curve,
      builder: (_, child) {
        final t = curve.value;
        Widget content = child!;
        if (allowBlur && t < 0.97) {
          final sigma = Reveal.maxBlurSigma * (1 - t);
          content = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: content,
          );
        }
        return Opacity(
          opacity: t.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, widget.offset * (1 - t)),
            child: Transform.scale(
              scale: widget.scaleFrom + (1 - widget.scaleFrom) * t,
              child: content,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
