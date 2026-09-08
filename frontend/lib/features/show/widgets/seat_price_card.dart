import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/seat_price.dart';

/// 등급별 가격 카드. 등급이 여럿이면 줄이 늘고 사이에 구분선이 들어간다.
class SeatPriceCard extends StatelessWidget {
  const SeatPriceCard({super.key, required this.seatPrices});

  final List<SeatPrice> seatPrices;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(ShowDetailMetrics.cardRadius),
      ),
      child: Column(
        children: [
          for (var index = 0; index < seatPrices.length; index++) ...[
            if (index > 0) const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      seatPrices[index].grade,
                      style: textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    seatPrices[index].priceLabel,
                    style: textTheme.titleSmall,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
