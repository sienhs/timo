import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/poster_image.dart';
import '../constants.dart';
import '../models/listable_ticket.dart';
import 'resale_card.dart';

/// 양도 등록 화면에서 고르는 내 티켓 카드.
///
/// 고른 카드는 테두리와 바탕이 함께 바뀐다([ResaleCard]). 가격을 정하는
/// 단계에서는 고른 카드 하나만 남고, 그때는 누를 수 없다([onTap] 이 null).
class ListableTicketCard extends StatelessWidget {
  const ListableTicketCard({
    super.key,
    required this.ticket,
    required this.selected,
    this.onTap,
    this.showFacePrice = false,
  });

  final ListableTicket ticket;
  final bool selected;
  final VoidCallback? onTap;

  /// 정가를 한 줄 더 보여 줄지. 가격을 정하는 단계에서만 참이다 — 고르는
  /// 단계에서는 아직 값이 필요 없고, 정하는 단계에서는 상한이라 필요하다.
  final bool showFacePrice;

  @override
  Widget build(BuildContext context) {
    final startAt = ticket.startAt;

    return Semantics(
      selected: selected,
      button: onTap != null,
      child: ResaleCard(
        onTap: onTap,
        selected: selected,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: ResaleMetrics.posterWidth,
              height: ResaleMetrics.posterHeight,
              child: PosterImage.network(
                url: ticket.posterImageUrl,
                borderRadius: ResaleMetrics.posterRadius,
                decodeWidth: ResaleMetrics.posterWidth,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket.concertTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  ResaleInfoLine(
                    icon: Icons.calendar_today_outlined,
                    text: startAt == null
                        ? ResaleStrings.dateUndecided
                        : formatPerformedAt(startAt),
                  ),
                  ResaleInfoLine(
                    icon: Icons.place_outlined,
                    text: ticket.venueName,
                  ),
                  ResaleInfoLine(
                    icon: Icons.event_seat_outlined,
                    text: ticket.seatLabel,
                  ),
                  if (showFacePrice) ...[
                    const SizedBox(height: 6),
                    Text(
                      ResaleStrings.faceValueOf(formatMsr(ticket.facePrice)),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
