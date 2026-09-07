import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 입력칸 오른쪽에 붙는 작은 '중복 확인' 버튼.
///
/// `onPressed` 가 null 이면 비활성. [isChecking] 이면 글자 대신 스피너를
/// 보여주고 눌리지 않는다.
class DuplicateCheckButton extends StatelessWidget {
  const DuplicateCheckButton({
    super.key,
    required this.onPressed,
    this.isChecking = false,
  });

  final VoidCallback? onPressed;
  final bool isChecking;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return OutlinedButton(
      // 테마의 minimumSize 는 Size.fromHeight(46) 로 폭이 무한이라, 입력칸 옆
      // Row 안에 두면 "infinite width" 로 터진다. 높이는 입력칸과 같게 맞춘다.
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, AuthMetrics.fieldHeight),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        foregroundColor: AppColors.textPrimary,
        textStyle: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      onPressed: isChecking ? null : onPressed,
      // 글자를 숨기되 자리는 남겨 두어 스피너로 바뀌어도 버튼 폭이 안 변한다.
      child: Stack(
        alignment: Alignment.center,
        children: [
          Visibility(
            visible: !isChecking,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: const Text(AuthStrings.duplicateCheck),
          ),
          if (isChecking)
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}
