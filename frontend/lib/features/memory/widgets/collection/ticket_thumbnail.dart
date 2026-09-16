import 'package:flutter/material.dart';

import '../../models/memory_ticket.dart';
import '../../theme/timo_colors.dart';
import '../ui/gradient_text.dart';
import '../ui/local_image.dart';
import '../../constants.dart';

/// Still picture of a ticket for lists: the dark card frame, the stage
/// photo, the person cutout and the brand strip. No shaders or sensors, so
/// a grid full of these stays cheap. [personShift] nudges the person
/// sideways (carousel parallax).
class TicketThumbnail extends StatelessWidget {
  const TicketThumbnail({
    super.key,
    required this.ticket,
    this.personShift = Offset.zero,
    this.radius = 16,
    this.showBrand = true,
  });
  final MemoryTicket ticket;
  final Offset personShift;
  final double radius;
  final bool showBrand;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFF15181F),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius - 3),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF0B0F1A)),
          LocalImage(ticket.backgroundPath, fit: BoxFit.cover, cacheWidth: 600),
          if (ticket.personCompositePath != null)
            Transform.translate(
              offset: personShift,
              child: Transform.scale(
                scale: ticket.manualPersonLayout
                    ? 1
                    : ViewerConstants.personScale,
                child: LocalImage(
                  ticket.personCompositePath!,
                  fit: BoxFit.contain,
                  cacheWidth: 600,
                ),
              ),
            ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x66000000),
                    Color(0x00000000),
                    Color(0x8C000000),
                  ],
                  stops: [0, 0.3, 1],
                ),
              ),
            ),
          ),
          if (showBrand) ...[
            Positioned(
              left: 12,
              top: 10,
              child: Text(
                'INTERACTIVE MEMORY',
                style: TextStyle(
                  fontSize: 7,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ticket.details['공연명'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          ticket.details['날짜'] ?? '',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GradientText(
                    'TIMO',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Empty catalogue cell: a soft grey card the same shape as a ticket.
class TicketPlaceholder extends StatelessWidget {
  const TicketPlaceholder({super.key, this.radius = 16, this.child});
  final double radius;
  final Widget? child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: TimoColors.placeholder,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: child,
  );
}
