import 'package:flutter/painting.dart';

import '../../../core/theme/app_colors.dart';
import '../models/seat.dart';

/// 좌석 상태 → 색 표. 범례와 배치도가 반드시 같은 색을 써야 하므로 한 곳에서만
/// 정의한다.
({Color fill, Color border}) seatCellColors(
  SeatCellState state, {
  Color? zoneColor,
}) => switch (state) {
  SeatCellState.available => (
    fill: zoneColor ?? AppColors.seatAvailable,
    border: zoneColor ?? AppColors.seatAvailable,
  ),
  SeatCellState.selected => (
    fill: (zoneColor ?? AppColors.seatAvailable).withValues(alpha: .18),
    border: zoneColor ?? AppColors.seatAvailable,
  ),
  SeatCellState.sold => (fill: AppColors.seatSold, border: AppColors.seatSold),
};

/// 좌석 칸 모서리를 한 변의 몇 배로 깎을지. 0.5 면 완전한 원이다. 크기가 다른
/// 범례 칩과 배치도 칸이 같은 모양으로 보이도록 길이가 아니라 비율로 둔다.
const seatCellRadiusRatio = 0.34;

/// 범례에 노출할 이름과 순서. 시안과 같은 3종이다.
const seatLegendLabels = <SeatCellState, String>{
  SeatCellState.available: '예매가능',
  SeatCellState.selected: '선택됨',
  SeatCellState.sold: '선택불가',
};
