import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// 불러오는 동안 내용 자리에 두는 회색 상자. 카드 줄과 배너가 같이 쓴다.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
