import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/timo_colors.dart';

/// Frosted glass surface with a hairline border and a top-left highlight.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = TimoRadii.panel,
    this.blur = 18,
    this.color = TimoColors.glass,
    this.borderColor = TimoColors.glassBorder,
    this.borderWidth = 1,
    this.glow,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final Color color;
  final Color borderColor;
  final double borderWidth;
  final Color? glow;
  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: glow == null
            ? null
            : [
                BoxShadow(
                  color: glow!.withValues(alpha: 0.35),
                  blurRadius: 28,
                  spreadRadius: -4,
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color,
              borderRadius: shape,
              border: Border.all(color: borderColor, width: borderWidth),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x1AFFFFFF), Color(0x00FFFFFF)],
                stops: [0, 0.55],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
