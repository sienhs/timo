import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'seat_colors.dart';

/// 좌석 상태 범례. 시안의 3종에 '선점중'을 더해 4종을 노출한다.
class SeatLegend extends StatelessWidget {
  const SeatLegend({super.key});

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
              colors: seatCellColors(entry.key),
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
