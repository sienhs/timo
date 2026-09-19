import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'seat_colors.dart';

/// 좌석 상태 범례. 시안과 같은 3종이다.
///
/// 선점중은 따로 내지 않는다. 배치도가 그것을 예매 완료와 같은 회색으로
/// 그리기 때문이다(`seatCellStateOf`). 남이 잡아 둔 자리든 팔린 자리든
/// 지금 고를 수 없다는 점에서 같고, 나누면 "기다리면 풀리나" 라는 기대를
/// 만든다.
class SeatLegend extends StatelessWidget {
  const SeatLegend({super.key, this.zoneColor});
  final Color? zoneColor;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelMedium;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final entry in seatLegendLabels.entries)
            _LegendChip(
              label: entry.value,
              colors: seatCellColors(entry.key, zoneColor: zoneColor),
              labelStyle: labelStyle,
            ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.label,
    required this.colors,
    required this.labelStyle,
  });

  final String label;
  final ({Color fill, Color border}) colors;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: colors.fill,
            border: Border.all(color: colors.border, width: 1),
            borderRadius: const BorderRadius.all(Radius.circular(2)),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: labelStyle),
      ],
    );
  }
}
