import 'package:flutter/material.dart';

import '../../motion/press_scale.dart';
import '../../theme/timo_colors.dart';
import '../ui/paper_card.dart';

/// MemoryConcert pick: poster, facts with icons, and a full-width action that
/// starts the collectible for this concert. Takes plain values so it does
/// not depend on another domain.
class ConcertCard extends StatelessWidget {
  const ConcertCard({
    super.key,
    required this.title,
    required this.date,
    required this.venue,
    required this.seat,
    required this.poster,
    required this.selected,
    required this.actionLabel,
    required this.onTap,
    required this.onAction,
  });
  final String title, date, venue, seat, poster, actionLabel;
  final bool selected;
  final VoidCallback onTap, onAction;

  @override
  Widget build(BuildContext context) => PressScale(
    onTap: onTap,
    lift: 1,
    child: PaperCard(
      selected: selected,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  poster,
                  width: 64,
                  height: 88,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: TimoColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _Fact(Icons.calendar_today_outlined, date),
                    _Fact(Icons.place_outlined, venue),
                    _Fact(Icons.event_seat_outlined, seat),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onAction,
            style: selected
                ? OutlinedButton.styleFrom(
                    backgroundColor: TimoColors.brandSoft,
                  )
                : null,
            child: Text(actionLabel),
          ),
        ],
      ),
    ),
  );
}

class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(
      children: [
        Icon(icon, size: 12, color: TimoColors.inkTertiary),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: TimoColors.inkSecondary,
            ),
          ),
        ),
      ],
    ),
  );
}
