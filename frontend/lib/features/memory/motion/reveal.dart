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
  // 필드 초기화로 미루면(late final) 한 번도 안 쓰인 채 사라질 때 dispose 가
  // 그제서야 컨트롤러를 만든다. 그 시점의 element 는 이미 죽어 있어 Ticker 가
  // 조상을 찾다 터진다 — 동작 줄이기를 켠 화면이 정확히 그 길이다.
  late final AnimationController controller;
  late final CurvedAnimation curve;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: widget.duration);
    curve = CurvedAnimation(parent: controller, curve: Motion.emphasized);
    final wait = widget.delay + Motion.stagger * widget.index;
    timer = Timer(wait, () {
      if (mounted) controller.forward();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    curve.dispose();
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
