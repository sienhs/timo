import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// 포스터 왼쪽 위에 얹는 작은 배지. `D-9` · `D-DAY`. 글자가 작아 브랜드 초록 위
/// 흰 글자로는 대비가 모자라(3.43:1) 바탕을 [AppColors.primaryPressed] 로 깐다.
class TicketBadge extends StatelessWidget {
  const TicketBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.primaryPressed,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
