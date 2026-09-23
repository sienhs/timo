import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'seat_colors.dart';

/// 좌석 상태 범례. 시안과 같은 3종이다. 선점중은 배치도가 예매 완료와 같은
/// 회색으로 그리므로(`seatCellStateOf`) 따로 내지 않는다.
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

/// 범례 칩 한 변.
const _chipSize = 11.0;

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
          width: _chipSize,
          height: _chipSize,
          decoration: BoxDecoration(
            color: colors.fill,
            border: Border.all(color: colors.border, width: 1),
            // 배치도 칸과 같은 비율로 깎는다. 범례가 네모인데 자리가 둥글면
            // 같은 것을 가리키는 표시로 읽히지 않는다.
            borderRadius: const BorderRadius.all(
              Radius.circular(_chipSize * seatCellRadiusRatio),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: labelStyle),
      ],
    );
  }
}
