import 'package:flutter/material.dart';

import 'motion_tokens.dart';

/// Integer that eases from its previous value to the new one instead of
/// jumping (anime.js-style value interpolation).
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber(this.value, {super.key, required this.style});
  final int value;
  final TextStyle style;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: value.toDouble()),
    duration: Motion.reduced(context) ? Duration.zero : Motion.slow,
    curve: Motion.emphasized,
    builder: (_, v, _) => Text(
      v.round().toString(),
      style: style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    ),
  );
}
