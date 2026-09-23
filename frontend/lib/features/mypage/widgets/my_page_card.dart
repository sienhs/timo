import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 마이페이지의 초록 테두리 카드. 잔액 카드와 사용 내역 카드가 같은 틀을 쓴다.
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
