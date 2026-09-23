import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/quick_menu_item.dart';

/// 하단 바 위에 뜨는 빠른 메뉴 패널을 연다. 고른 항목을 돌려주고 밖을 눌러 닫았으면
/// null 이다. 라우팅·안내는 호출부가 한다. [showDialog] 는 화면을 어둡게 덮어 하단
/// 바가 가려지므로 배리어가 투명한 [showGeneralDialog] 를 쓴다.
Future<QuickMenuItem?> showQuickMenu(BuildContext context) {
  return showGeneralDialog<QuickMenuItem>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    barrierLabel: ShellStrings.quickMenuBarrier,
    transitionDuration: ShellMetrics.panelTransition,
    pageBuilder: (context, _, _) => const _QuickMenuPanel(),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      if (MediaQuery.disableAnimationsOf(context)) {
        return FadeTransition(opacity: curved, child: child);
      }
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: ShellMetrics.panelSlideOffset,
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _QuickMenuPanel extends StatelessWidget {
  const _QuickMenuPanel();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          ShellMetrics.panelHorizontalMargin,
          0,
          ShellMetrics.panelHorizontalMargin,
          ShellMetrics.barHeight +
              ShellMetrics.fabProtrusion +
              bottomInset +
              ShellMetrics.panelGap,
        ),
        child: Material(
          color: AppColors.surface,
          borderRadius: const BorderRadius.all(
            Radius.circular(ShellMetrics.panelRadius),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(
                Radius.circular(ShellMetrics.panelRadius),
              ),
              border: Border.all(color: AppColors.primary),
            ),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
            child: const _QuickMenuGrid(),
          ),
        ),
      ),
    );
  }
}

/// 4열 격자. 행 수는 항목 수에서 나온다. GridView 는 스스로 높이를 정하지 못해
/// shrinkWrap · 비율 지정이 따라붙으므로 Row 를 쌓는다.
class _QuickMenuGrid extends StatelessWidget {
  const _QuickMenuGrid();

  @override
  Widget build(BuildContext context) {
    const columns = ShellMetrics.quickMenuColumns;
    final rows = <Widget>[];

    for (var start = 0; start < quickMenuItems.length; start += columns) {
      final end = (start + columns).clamp(0, quickMenuItems.length);
      final cells = quickMenuItems.sublist(start, end);
      rows.add(
        Row(
          children: [
            for (final item in cells) Expanded(child: _QuickMenuCell(item)),
            // 마지막 줄이 덜 찼을 때 남은 칸을 비워 정렬을 유지한다.
            for (var i = cells.length; i < columns; i++) const Spacer(),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 22),
          rows[i],
        ],
      ],
    );
  }
}

class _QuickMenuCell extends StatelessWidget {
  const _QuickMenuCell(this.item);

  final QuickMenuItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: () => Navigator.pop(context, item),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            item.customIcon ??
                Icon(
                  item.icon,
                  size: ShellMetrics.panelIconSize,
                  color: AppColors.textPrimary,
                ),
            const SizedBox(height: 8),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelMedium?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
