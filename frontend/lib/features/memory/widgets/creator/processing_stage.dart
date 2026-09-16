import 'package:flutter/material.dart';

import '../../motion/motion_tokens.dart';
import '../../motion/reveal.dart';
import '../../motion/staggered_text.dart';
import '../../theme/timo_colors.dart';
import '../../constants.dart';
import 'gift_box.dart';

enum ProcessingPhase { running, done, failed }

/// "제작중" body: headline, gift box, status line. The route owns the
/// bottom button so this stays a display widget.
class ProcessingStage extends StatelessWidget {
  const ProcessingStage({super.key, required this.phase, required this.status});
  final ProcessingPhase phase;

  /// Current pipeline step (running) or the failure message (failed).
  final String status;

  String get title => switch (phase) {
    ProcessingPhase.running => CreatorText.processingTitle,
    ProcessingPhase.done => CreatorText.doneTitle,
    ProcessingPhase.failed => CreatorText.failedTitle,
  };
  String get body => switch (phase) {
    ProcessingPhase.running => CreatorText.processingBody,
    ProcessingPhase.done => CreatorText.doneBody,
    ProcessingPhase.failed => CreatorText.failedBody,
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      StaggeredText(
        title,
        key: ValueKey('processing-title-$phase'),
        style: Theme.of(context).textTheme.headlineMedium!,
      ),
      const SizedBox(height: 8),
      Reveal(
        key: ValueKey('processing-body-$phase'),
        index: 1,
        child: Text(body, style: Theme.of(context).textTheme.bodyMedium),
      ),
      const SizedBox(height: 28),
      Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Reveal(
                index: 2,
                scaleFrom: 0.9,
                child: GiftBox(
                  size: CreatorLayout.giftSize,
                  celebrate: phase == ProcessingPhase.done,
                ),
              ),
              const SizedBox(height: 24),
              AnimatedSwitcher(
                duration: Motion.base,
                child: Text(
                  phase == ProcessingPhase.done
                      ? CreatorText.notificationTitle
                      : status,
                  key: ValueKey(status + phase.name),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: phase == ProcessingPhase.failed
                        ? TimoColors.dangerInk
                        : TimoColors.inkSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                CreatorText.onDeviceNote,
                style: TextStyle(fontSize: 11.5, color: TimoColors.inkTertiary),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
