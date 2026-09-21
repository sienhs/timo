import 'package:flutter/material.dart';

import '../../motion/press_scale.dart';
import '../../theme/timo_colors.dart';
import '../ui/paper_card.dart';

/// 소장품을 만들 공연 하나. 포스터와 사실 몇 줄이 전부다.
///
/// 카드마다 버튼을 달지 않는다. 고른 것은 초록 테두리가 말하고, 다음으로 가는
/// 버튼은 화면 아래 하나뿐이다 — 버튼이 카드 수만큼 서 있으면 무엇을 눌러야
/// 넘어가는지가 흐려진다. 다른 도메인을 모르도록 값만 받는다.
class ConcertCard extends StatelessWidget {
  const ConcertCard({
    super.key,
    required this.title,
    required this.date,
    required this.venue,
    required this.seat,
    required this.poster,
    required this.selected,
    required this.onTap,
  });
  final String title, date, venue, seat, poster;
  final bool selected;
  final VoidCallback onTap;

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
