import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 본문에 보여 줄 것이 없을 때의 자리. 한 줄 안내와, 있으면 버튼 하나.
///
/// 빈 목록(매물이 없다·티켓이 없다)과 로그인 안내가 같은 모양을 쓴다. 둘 다
/// "지금 여기서 볼 것이 없다" 는 같은 사정이고, 다른 것은 문구와 다음에 할 일
/// 뿐이다.
class ResaleEmptyView extends StatelessWidget {
  const ResaleEmptyView({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;

  /// 다음에 할 일. 라벨과 동작이 함께 있을 때만 버튼을 그린다.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    final onAction = this.onAction;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ResaleMetrics.horizontalPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            if (label != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAction, child: Text(label)),
            ],
          ],
        ),
      ),
    );
  }
}
