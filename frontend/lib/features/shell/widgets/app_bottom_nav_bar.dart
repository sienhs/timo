import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 앱 전역 하단 바. 홈 · 빠른 메뉴 · 마이페이지 3분할이다.
///
/// 가운데 원형 버튼은 이 위젯에 없다. 탭이 아니라 빠른 메뉴 토글이고 바 위로
/// 솟아 있어서 `Scaffold.floatingActionButton` 이 그린다([QuickMenuButton]).
/// 바 안쪽에는 가운데 칸의 라벨만 남는다.
///
/// 그래서 [selectedIndex] 는 0(홈) · 1(마이페이지) 둘뿐이다.
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.onQuickMenuPressed,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  /// 가운데 '빠른 메뉴' 라벨을 눌렀을 때. 원형 버튼과 같은 동작이다.
  final VoidCallback onQuickMenuPressed;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: ShellMetrics.barHeight,
          child: Row(
            children: [
              Expanded(
                child: _NavTab(
                  icon: Icons.home_outlined,
                  label: ShellStrings.homeTab,
                  selected: selectedIndex == 0,
                  onTap: () => onTabSelected(0),
                ),
              ),
              // 가운데 칸은 라벨만 있다. 아이콘 자리는 위로 솟은 원형 버튼이
              // 차지하므로 아이콘 높이만큼 비워 라벨 줄을 양옆과 맞춘다.
              Expanded(
                child: _NavTab(
                  label: ShellStrings.quickMenuTab,
                  selected: false,
                  onTap: onQuickMenuPressed,
                ),
              ),
              Expanded(
                child: _NavTab(
                  icon: Icons.person_outline,
                  label: ShellStrings.myPageTab,
                  selected: selectedIndex == 1,
                  onTap: () => onTabSelected(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final IconData? icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // 색만으로 구분하지 않도록 선택 상태는 굵기도 함께 바꾼다.
    final color = selected ? AppColors.primary : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: ShellMetrics.navIconSize,
            child: icon == null
                ? null
                : Icon(icon, size: ShellMetrics.navIconSize, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: selected ? FontWeight.w700 : null,
            ),
          ),
        ],
      ),
    );
  }
}
