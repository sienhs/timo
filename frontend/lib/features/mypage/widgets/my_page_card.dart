import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 마이페이지의 초록 테두리 카드. 잔액 카드와 사용 내역 카드가 같은 틀을 쓴다.
///
/// 둘의 테두리·모서리·안쪽 여백이 어긋나면 위아래로 놓였을 때 바로 눈에
/// 띄므로 한 곳에 둔다.
class MyPageCard extends StatelessWidget {
  const MyPageCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MyPageMetrics.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(MyPageMetrics.cardRadius),
        border: Border.all(
          color: AppColors.primary,
          width: MyPageMetrics.cardBorderWidth,
        ),
      ),
      child: child,
    );
  }
}
