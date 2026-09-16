import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../motion/ambient_motion.dart';
import '../../motion/motion_tokens.dart';
import '../../motion/press_scale.dart';
import '../../theme/timo_colors.dart';

/// Primary call-to-action: TIMO green on paper. Press → the button sinks on
/// a spring and its shadow tightens ([AmbientMotion.pressGlow] still fires so
/// dark screens with an aurora respond too). Release → springs back.
class GlowButton extends StatefulWidget {
  const GlowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  State<GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<GlowButton>
    with SingleTickerProviderStateMixin {
  /// 0 = idle, 1 = pressed. Same spring as the scale so they land together.
  late final AnimationController glow = AnimationController.unbounded(
    vsync: this,
    value: 0,
  );

  void press(bool down) {
    glow.animateWith(
      SpringSimulation(Motion.pressSpring, glow.value, down ? 1 : 0, 0),
    );
    AmbientMotion.instance.pressGlow(down);
  }

  @override
  void dispose() {
    glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: PressScale(
        enabled: enabled,
        onTap: widget.onPressed,
        onPressChanged: press,
        lift: 1.5,
        child: AnimatedBuilder(
          animation: glow,
          builder: (_, child) {
            final g = glow.value.clamp(0.0, 1.0);
            return AnimatedContainer(
              duration: Motion.base,
              curve: Motion.standard,
              height: 52,
              decoration: BoxDecoration(
                color: enabled
                    ? Color.lerp(TimoColors.brandMid, TimoColors.brand, g)
                    : TimoColors.placeholder,
                borderRadius: BorderRadius.circular(12),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: TimoColors.brandMid.withValues(
                            alpha: 0.35 + 0.15 * g,
                          ),
                          blurRadius: 22 - 8 * g,
                          offset: Offset(0, 9 - 5 * g),
                        ),
                      ]
                    : null,
              ),
              child: child,
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 20,
                  color: enabled ? Colors.white : TimoColors.inkTertiary,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: enabled ? Colors.white : TimoColors.inkTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
