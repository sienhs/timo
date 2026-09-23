import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/timo_mascot.dart';
import '../constants.dart';

/// 본문에 보여 줄 것이 없을 때의 자리. 우는 티모와 한 줄 안내, 있으면 버튼 하나.
/// 빈 목록과 로그인 안내가 같은 모양을 쓴다. [showMascot] 을 끄는 자리는 로그인
/// 안내다 — 허탕이 아니라 아직 로그인을 안 한 것이라 우는 얼굴이 어울리지 않는다.
class ResaleEmptyView extends StatelessWidget {
  const ResaleEmptyView({
    super.key,
    required this.message,
    this.showMascot = true,
    this.actionLabel,
    this.onAction,
  });

  final String message;

  /// 안내 위에 우는 티모를 그릴지.
  final bool showMascot;

  /// 다음에 할 일. 라벨과 동작이 함께 있을 때만 버튼을 그린다.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    final onAction = this.onAction;

    // 자리가 넉넉하면 한가운데, 좁으면 스크롤. 검색 중 키보드가 화면 아래
    // 절반을 가져갈 때 마스코트째로 잘리는 대신 밀어서 볼 수 있게 한다.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ResaleMetrics.horizontalPadding,
                vertical: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showMascot) ...[
                    const TimoMascot.sad(size: ResaleMetrics.emptyMascotSize),
                    const SizedBox(height: 20),
                  ],
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (label != null && onAction != null) ...[
                    const SizedBox(height: 16),
                    OutlinedButton(onPressed: onAction, child: Text(label)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
