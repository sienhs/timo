import 'package:flutter/painting.dart';

import '../../../core/theme/app_colors.dart';
import '../models/seat.dart';

/// 좌석 상태 → 색 표.
///
/// 범례와 배치도가 반드시 같은 색을 써야 하므로 한 곳에서만 정의한다.
/// 위젯마다 색을 적으면 시안이 바뀔 때 한쪽만 고치는 사고가 난다.
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

/// 좌석 칸 모서리를 한 변의 몇 배로 깎을지. 0.5 면 완전한 원이다.
///
/// 범례 칩과 배치도 칸이 같은 모양이어야 하므로 색과 같은 자리에 둔다.
/// 크기가 다른 둘에 같은 반경을 적어 두면 작은 칩만 동그래져 서로 다른
/// 모양으로 보인다. 그래서 길이가 아니라 비율로 둔다.
const seatCellRadiusRatio = 0.34;

/// 범례에 노출할 이름과 순서. 시안과 같은 3종이다.
const seatLegendLabels = <SeatCellState, String>{
  SeatCellState.available: '예매가능',
  SeatCellState.selected: '선택됨',
  SeatCellState.sold: '선택불가',
};
