import 'package:flutter/material.dart';

import '../../motion/motion_tokens.dart';
import '../../theme/timo_colors.dart';

/// White surface for the light chrome: hairline border, soft drop shadow,
/// and a green outline when [selected]. Counterpart of the dark [GlassPanel].
class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = TimoRadii.tile,
    this.selected = false,
    this.elevated = true,
    this.color = TimoColors.paper,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool selected;
  final bool elevated;
  final Color color;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: Motion.base,
    curve: Motion.standard,
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: selected ? TimoColors.brandMid : TimoColors.line,
        width: selected ? 1.6 : 1,
      ),
      boxShadow: elevated
          ? [
              BoxShadow(
                color: (selected ? TimoColors.brandMid : TimoColors.ink)
                    .withValues(alpha: selected ? 0.18 : 0.06),
                blurRadius: selected ? 22 : 16,
                offset: const Offset(0, 6),
              ),
            ]
          : null,
    ),
    child: child,
  );
}
