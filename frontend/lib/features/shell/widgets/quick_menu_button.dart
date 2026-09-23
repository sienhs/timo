import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// [QuickMenuButton] 의 배치. 가로 가운데, 바 위로
/// [ShellMetrics.fabProtrusion] 만큼만 솟는다.
const quickMenuButtonLocation = _QuickMenuFabLocation();

/// 도킹 배치를 그대로 쓰되 솟는 높이만 줄인다. 계산을 새로 하지 않고 기본 도킹
/// 결과에서 차이만큼 내리는 것은, 스낵바·바텀시트가 뜰 때 버튼을 비켜 주는
/// 처리가 도킹 배치 안에 들어 있기 때문이다.
class _QuickMenuFabLocation extends StandardFabLocation
    with FabCenterOffsetX, FabDockedOffsetY {
  const _QuickMenuFabLocation();

  @override
  double getOffsetY(
    ScaffoldPrelayoutGeometry scaffoldGeometry,
    double adjustment,
  ) =>
      super.getOffsetY(scaffoldGeometry, adjustment) +
      ShellMetrics.fabSize / 2 -
      ShellMetrics.fabProtrusion;
}

/// 하단 바 가운데에서 위로 솟은 원형 토글.
/// 바 안에 두지 않고 `Scaffold.floatingActionButton` 으로 띄운다. 바 안에 두면
/// 솟은 만큼 바가 높아져 흰 띠가 두 겹으로 보이고, 박스 밖으로 나가 탭이 안 먹는다.
class QuickMenuButton extends StatelessWidget {
  const QuickMenuButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: ShellMetrics.fabSize,
      child: Material(
        color: AppColors.primary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Semantics(
            button: true,
            label: ShellStrings.openQuickMenu,
            child: const Icon(
              Icons.add,
              size: ShellMetrics.fabIconSize,
              color: AppColors.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
