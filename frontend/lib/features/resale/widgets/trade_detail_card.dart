import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/poster_image.dart';
import '../constants.dart';
import '../models/purchased_trade.dart';
import 'resale_summary_card.dart';

/// 결제 완료 화면의 거래 요약 카드. 공연명 · 일시 · 구역 · 결제 금액.
class TradeDetailCard extends StatelessWidget {
  const TradeDetailCard({super.key, required this.trade});

  final PurchasedTrade trade;

  @override
  Widget build(BuildContext context) {
    final startAt = trade.startAt;

    return ResaleSummaryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ResaleInfoRow(
            label: ResaleStrings.concertLabel,
            value: trade.concertTitle,
          ),
          ResaleInfoRow(
            label: ResaleStrings.performedAtLabel,
            value: startAt == null
                ? ResaleStrings.dateUndecided
                : formatPerformedAt(startAt),
          ),
          // 체결 응답이 좌석을 실어 주면 `A구역 9열 6번`, 아니면 구역명만이다.
          ResaleInfoRow(label: ResaleStrings.seatLabel, value: trade.seatLabel),
          ResaleInfoRow(
            label: ResaleStrings.paidAmountLabel,
            value: formatMsr(trade.price),
            valueColor: AppColors.accent,
          ),
        ],
      ),
    );
  }
}

/// 완료 화면 위쪽의 원형 포스터. 코랄 테두리를 두르고, 그림은 공통
/// 위젯([PosterImage])에 맡긴다.
class TradePosterAvatar extends StatelessWidget {
  const TradePosterAvatar({
    super.key,
    required this.url,
    this.diameter = ResaleMetrics.completePosterDiameter,
  });

  final String? url;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.accent, width: 2),
      ),
      // 테두리 안쪽으로 그림을 넣는다. 테두리와 그림이 맞닿아 있으면 원이
      // 두 겹으로 보인다.
      padding: const EdgeInsets.all(3),
      child: PosterImage.network(
        url: url,
        borderRadius: diameter / 2,
        decodeWidth: diameter,
      ),
    );
  }
}
