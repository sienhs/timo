import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_action_button.dart';
import '../constants.dart';

/// 화면 맨 아래 고정되는 행동 자리. 안내 한 줄 + 버튼 하나.
///
/// 양도마켓의 모든 화면이 아래쪽에 버튼 하나를 둔다. 여백과 배경을 화면마다
/// 적으면 버튼 높이가 화면마다 미세하게 달라 보인다.
class ResaleBottomBar extends StatelessWidget {
  const ResaleBottomBar({
    super.key,
    required this.child,
    this.notice,
    this.noticeColor = AppColors.accent,
  });

  /// 보통 [ResaleActionButton] 하나. 완료 화면처럼 두 개가 필요하면 Column 이다.
  final Widget child;

  /// 버튼 위에 놓는 한 줄. 없으면 그 자리를 비운다.
  final String? notice;

  final Color noticeColor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ResaleMetrics.horizontalPadding,
            12,
            ResaleMetrics.horizontalPadding,
            12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (notice case final notice?) ...[
                Text(
                  notice,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: noticeColor),
                ),
                const SizedBox(height: 10),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// 하단의 주요 버튼. 시안의 꽉 찬 초록 버튼과 테두리 버튼 두 가지다.
///
/// 비활성이어도 주요/보조 행동의 종류는 유지한다.
class ResaleActionButton extends StatelessWidget {
  const ResaleActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = true,
  });

  final String label;
  final VoidCallback? onPressed;

  /// 꽉 찬 초록 버튼인지. 한 화면에서 가장 중요한 행동 하나에만 참이다.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return AppActionButton(
      label: label,
      onPressed: onPressed,
      variant: filled ? AppActionStyle.primary : AppActionStyle.secondary,
    );
  }
}
