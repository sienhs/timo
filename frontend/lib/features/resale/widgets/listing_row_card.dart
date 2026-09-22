import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../constants.dart';
import '../models/listing.dart';
import 'resale_card.dart';

/// 매물 목록의 한 줄. 구역 · 등록가 · 회차 · 정가 · 할인율.
///
/// 첫 칸은 `S구역 8열 19번` 까지 찍는다(사용자 결정). 서버가 좌석을 아직 안
/// 실어 주면 구역명만 남는다([Listing.seatLabel]).
///
/// [performedAt] 은 공연 회차다. 매물 응답에 공연 정보가 없어(같은 공연의
/// 매물이라 반복해 실을 이유가 없다) 화면이 고른 공연에서 받아 넘긴다.
///
/// 내 매물도 **누를 수 있다.** 살 수는 없지만 내릴 수 있어서다. 어느 쪽인지는
/// 화면이 [Listing.mine] 을 보고 가른다([onTap] 하나로 받는다) — 카드는 눌린
/// 것만 알린다.
class ListingRowCard extends StatelessWidget {
  const ListingRowCard({
    super.key,
    required this.listing,
    required this.performedAt,
    required this.onTap,
  });

  final Listing listing;

  /// 공연 회차 표시. 일정이 아직 없으면 null 이다.
  final DateTime? performedAt;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final performedAt = this.performedAt;

    return ResaleCard(
      // 내 매물도 누를 수 있다. 구매로 가지 않고 등록 취소 팝업이 열린다 —
      // 내릴 길이 내 티켓 탭에만 있으면 여기서 내 매물을 보고도 손을 못 댄다.
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  listing.seatLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                formatMsr(listing.price),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  performedAt == null
                      ? ResaleStrings.dateUndecided
                      : ResaleStrings.roundLabel(
                          '${formatMonthDayWithWeekday(performedAt)} '
                          '${formatClock(performedAt)}',
                        ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                formatMsr(listing.faceValue),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textDisabled,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: AppColors.textDisabled,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                ResaleStrings.discountRate(listing.discountRate),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryPressed,
                ),
              ),
            ],
          ),
          if (listing.mine) ...[
            const SizedBox(height: 10),
            const ResaleChip(
              label: ResaleStrings.ownListingDelist,
              background: ResaleColors.mineBackground,
              foreground: ResaleColors.mineForeground,
              icon: Icons.person_outline,
            ),
          ],
        ],
      ),
    );
  }
}
