import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/poster_image.dart';
import '../constants.dart';
import '../models/market_concert.dart';
import 'resale_card.dart';

/// 공연 선택 화면의 카드 한 장. 포스터 · 공연 정보 · 매물 수.
///
/// 값의 출처는 모른다. [MarketConcert] 객체 하나만 받아 그린다.
class MarketConcertCard extends StatelessWidget {
  const MarketConcertCard({
    super.key,
    required this.concert,
    required this.onTap,
  });

  final MarketConcert concert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final startAt = concert.startAt;

    return ResaleCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: ResaleMetrics.posterWidth,
            height: ResaleMetrics.posterHeight,
            child: PosterImage.network(
              url: concert.posterImageUrl,
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
                  concert.title,
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
                  text: concert.venueName,
                ),
                const SizedBox(height: 6),
                // 매물 수는 이 카드를 누를 이유 그 자체라 강조색으로 둔다.
                Text(
                  ResaleStrings.listingCount(concert.listingCount),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryPressed,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            size: 20,
            color: AppColors.textDisabled,
          ),
        ],
      ),
    );
  }
}
