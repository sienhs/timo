import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 예매 상태 뱃지. `오픈 예정` / `예매중` 두 가지뿐이다.
///
/// 색 조합을 밖에서 받지 않는다. 상태 뱃지는 색만으로 구분되면 안 되고
/// (색각 이상·흑백 출력) 배경 위 글자라 대비도 지켜야 해서, 두 조합을
/// 여기서 고정한다.
///
/// 시안의 연초록 배경 + 초록 글자는 대비가 4.41:1 이라 이만한 작은 글자에는
/// 못 쓴다. `예매중`은 홈의 오픈 뱃지와 같은 진한 그린(5.05:1), `오픈 예정`은
/// 회색 바탕에 검은 글자로 간다 — 색이 빠져도 문구로 구분된다.
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
