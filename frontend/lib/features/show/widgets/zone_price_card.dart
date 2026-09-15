import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/zone_price.dart';

/// 구역별 가격 카드. 구역이 여럿이면 줄이 늘고 사이에 구분선이 들어간다.
class ZonePriceCard extends StatelessWidget {
  const ZonePriceCard({super.key, required this.zonePrices});

  final List<ZonePrice> zonePrices;

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
          for (var index = 0; index < zonePrices.length; index++) ...[
            if (index > 0) const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      zonePrices[index].zoneName,
                      style: textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    zonePrices[index].priceLabel,
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
