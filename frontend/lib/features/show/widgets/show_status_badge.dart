import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 예매 상태 뱃지. `오픈 예정` / `예매중` 두 가지뿐이다. 색 조합은 밖에서 받지 않고
/// 여기서 고정한다 — 색만으로 구분되면 안 되고 배경 위 글자라 대비도 지켜야 한다.
/// `예매중`은 홈 오픈 뱃지와 같은 진한 그린(5.05:1), `오픈 예정`은 회색 바탕에 검은 글자다.
class ShowStatusBadge extends StatelessWidget {
  const ShowStatusBadge({super.key, required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOpen ? AppColors.primaryPressed : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(ShowDetailMetrics.badgeRadius),
        border: isOpen ? null : Border.all(color: AppColors.border),
      ),
      child: Text(
        isOpen
            ? ShowDetailStrings.onSaleBadge
            : ShowDetailStrings.upcomingBadge,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: isOpen ? AppColors.onPrimary : AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
