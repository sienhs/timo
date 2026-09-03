import 'package:flutter/painting.dart';

import '../../../core/theme/app_colors.dart';
import '../models/seat.dart';

/// 좌석 상태 → 색 표.
///
/// 범례와 배치도가 반드시 같은 색을 써야 하므로 한 곳에서만 정의한다.
/// 위젯마다 색을 적으면 시안이 바뀔 때 한쪽만 고치는 사고가 난다.
({Color fill, Color border, Color label}) seatCellColors(SeatCellState state) =>
    switch (state) {
      SeatCellState.available => (
          fill: AppColors.seatAvailable,
          border: AppColors.border,
          label: AppColors.textPrimary,
        ),
      SeatCellState.selected => (
          fill: AppColors.seatSelected,
          border: AppColors.seatSelected,
          label: AppColors.onPrimary,
        ),
      SeatCellState.sold => (
          fill: AppColors.seatSold,
          border: AppColors.seatSold,
          // 고를 수 없는 좌석이므로 번호를 낮은 대비로 눌러 둔다.
          label: AppColors.seatSoldLabel,
        ),
    };

/// 범례에 노출할 이름과 순서. 시안과 같은 3종이다.
const seatLegendLabels = <SeatCellState, String>{
  SeatCellState.available: '예매가능',
  SeatCellState.selected: '선택됨',
  SeatCellState.sold: '예매완료',
};
