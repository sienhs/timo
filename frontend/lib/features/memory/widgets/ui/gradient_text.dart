import 'package:flutter/material.dart';

import '../../theme/timo_colors.dart';

/// Text filled with a gradient (used for the TIMO wordmark).
class GradientText extends StatelessWidget {
  const GradientText(
    this.text, {
    super.key,
    required this.style,
    this.gradient = TimoGradients.wordmark,
  });
  final String text;
  final TextStyle style;
  final Gradient gradient;
  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: (bounds) =>
        gradient.createShader(Offset.zero & bounds.size),
    child: Text(text, style: style.copyWith(color: Colors.white)),
  );
}
