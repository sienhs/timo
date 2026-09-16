import 'package:flutter/material.dart';

import '../../motion/press_scale.dart';
import '../../theme/timo_colors.dart';

/// System-notification look-alike that drops in from the top when a
/// collectible finishes. Tap to open, swipe up to dismiss.
class CompletionBanner extends StatelessWidget {
  const CompletionBanner({
    super.key,
    required this.title,
    required this.body,
    required this.timeLabel,
    required this.onTap,
    required this.onDismiss,
  });
  final String title, body, timeLabel;
  final VoidCallback onTap, onDismiss;

  @override
  Widget build(BuildContext context) => Dismissible(
    key: const ValueKey('completion-banner'),
    direction: DismissDirection.up,
    onDismissed: (_) => onDismiss(),
    child: Semantics(
      button: true,
      liveRegion: true,
      label: '$title $body',
      child: PressScale(
        onTap: onTap,
        lift: 1,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: TimoColors.paper,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TimoColors.line),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2E000000),
                blurRadius: 28,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: TimoColors.brandSoft,
                ),
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  size: 18,
                  color: TimoColors.brandMid,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: TimoColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      body,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: TimoColors.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timeLabel,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: TimoColors.inkTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
