import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/poster_image.dart';
import '../constants.dart';
import '../models/listing_detail.dart';
import 'resale_summary_card.dart';

/// 구매 확인 화면의 매물 요약 카드. 공연 정보 + 정가·할인가 + 최종 금액.
///
/// 시안의 금액 줄은 `정가` · `할인가` · `TOTAL` 셋이다. 예매 결제 화면의
/// `티켓 가격` · `예매 수수료` 자리에 양도 매물의 값이 들어간 꼴이라 세로 흐름은
/// 같게 두었다 — 같은 결제 흐름에서 화면마다 배치가 바뀌면 값이 바뀐 것처럼
/// 읽힌다.
class ListingSummaryCard extends StatelessWidget {
  const ListingSummaryCard({super.key, required this.listing});

  final ListingDetail listing;

  @override
  Widget build(BuildContext context) {
    return ResaleSummaryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(listing: listing),
          const SizedBox(height: 18),
          const ResaleCardDivider(),
          ResaleInfoRow(
            label: ResaleStrings.faceValueLabel,
            value: formatMsr(listing.faceValue),
            valueColor: AppColors.primaryPressed,
          ),
          ResaleInfoRow(
            label: ResaleStrings.discountLabel,
            // 깎인 값이라는 게 부호로 드러나야 한다. 금액만 적으면 정가에
            // 더해지는 줄인지 빠지는 줄인지 알 수 없다.
            value: formatMsr(-listing.discountAmount),
            valueColor: AppColors.primaryPressed,
          ),
          const ResaleCardDivider(),
          _TotalRow(total: listing.price),
        ],
      ),
    );
  }
}

/// 공연 기본 정보(제목·일시·장소·구역)와 포스터.
class _Header extends StatelessWidget {
  const _Header({required this.listing});

  final ListingDetail listing;

  @override
  Widget build(BuildContext context) {
    final startAt = listing.startAt;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                listing.concertTitle,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              _MetaLine(
                startAt == null
                    ? ResaleStrings.dateUndecided
                    : formatPerformedAt(startAt),
              ),
              _MetaLine(listing.venueName),
              _MetaLine(listing.seatLabel),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 84,
          height: 112,
          child: PosterImage.network(
            url: listing.posterImageUrl,
            borderRadius: 8,
            decodeWidth: 84,
          ),
        ),
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }
}

/// 실제로 빠져나가는 금액. 다른 줄보다 크고 강조색을 쓴다.
class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Text(
            ResaleStrings.totalLabel,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              formatMsr(total),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
