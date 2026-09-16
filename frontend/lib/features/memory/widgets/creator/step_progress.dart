import 'package:flutter/material.dart';

import '../../motion/motion_tokens.dart';
import '../../theme/timo_colors.dart';

/// "1/5" counter with a thin bar underneath that fills as steps advance.
class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.step, required this.total});
  final int step, total;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '${step + 1}/$total',
        semanticsLabel: '$total단계 중 ${step + 1}단계',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: TimoColors.inkSecondary,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
      const SizedBox(height: 5),
      SizedBox(
        width: 56,
        height: 3,
        child: Stack(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: TimoColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
              child: const SizedBox.expand(),
            ),
            AnimatedFractionallySizedBox(
              duration: Motion.slow,
              curve: Motion.emphasized,
              widthFactor: (step + 1) / total,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: TimoColors.brandMid,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
