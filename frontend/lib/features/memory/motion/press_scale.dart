import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import 'motion_tokens.dart';

/// Physical press feedback (react-spring role): the child sinks slightly
/// while pressed and springs back on release. One spring drives scale and
/// lift together so they can never disagree.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.onTapDown,
    this.onPressChanged,
    this.enabled = true,
    this.lift = 0,
  });
  final Widget child;
  final VoidCallback? onTap;

  /// Where the finger landed (for selection focus effects).
  final ValueChanged<TapDownDetails>? onTapDown;

  /// Fires with `true` on press and `false` on release/cancel so the child
  /// can react (e.g. a thumbnail nudging), without owning the spring.
  final ValueChanged<bool>? onPressChanged;
  final bool enabled;

  /// Downward travel in px at full press.
  final double lift;
  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale>
    with SingleTickerProviderStateMixin {
  /// 0 = at rest, 1 = fully pressed.
  late final AnimationController press = AnimationController.unbounded(
    vsync: this,
    value: 0,
  );

  void animateTo(double target) => press.animateWith(
    SpringSimulation(Motion.pressSpring, press.value, target, 0),
  );

  void down(TapDownDetails details) {
    animateTo(1);
    widget.onTapDown?.call(details);
    widget.onPressChanged?.call(true);
  }

  void up() {
    animateTo(0);
    widget.onPressChanged?.call(false);
  }

  @override
  void dispose() {
    press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: widget.enabled ? down : null,
    onTapUp: widget.enabled ? (_) => up() : null,
    onTapCancel: widget.enabled ? up : null,
    onTap: widget.enabled ? widget.onTap : null,
    child: AnimatedBuilder(
      animation: press,
      builder: (_, child) {
        final p = press.value;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translateByDouble(0, widget.lift * p, 0, 1)
            ..scaleByDouble(
              1 - (1 - Motion.pressScale) * p,
              1 - (1 - Motion.pressScale) * p,
              1,
              1,
            ),
          child: child,
        );
      },
      child: widget.child,
    ),
  );
}
