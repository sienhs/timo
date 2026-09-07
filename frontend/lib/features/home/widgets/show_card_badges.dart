import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 포스터 위에 얹는 작은 라벨. 배경 위 글자라 대비를 지켜야 해서 색 조합을
/// 자유롭게 받지 않고 아래 두 종류만 만든다.
class _PosterBadge extends StatelessWidget {
  const _PosterBadge({
    required this.label,
    required this.background,
    required this.foreground,
    this.border,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final side = border;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(HomeMetrics.badgeRadius),
        border: side == null ? null : Border.all(color: side),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

/// 티켓 오픈 시각 뱃지. (예: `오늘 14:00 오픈`)
///
/// 배경은 [AppColors.primaryPressed] 다. 브랜드 그린([AppColors.primary]) 위에
/// 흰 글자는 대비가 3.43:1 이라 이렇게 작은 글자에는 못 쓴다 —
/// `AppColors.primary` 주석에 적힌 그대로다.
class TicketOpenBadge extends StatelessWidget {
  const TicketOpenBadge({super.key, required this.openAt, this.now});

  final DateTime openAt;

  /// 기준 시각. 테스트에서 `오늘`·`N일 후` 분기를 고정하려고 받는다.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return _PosterBadge(
      label: HomeStrings.ticketOpen(openAt, now: now ?? DateTime.now()),
      background: AppColors.primaryPressed,
      foreground: AppColors.onPrimary,
    );
  }
}

/// 인기 공연 순위 뱃지. (예: `1위`)
class RankBadge extends StatelessWidget {
  const RankBadge({super.key, required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    return _PosterBadge(
      label: HomeStrings.rank(rank),
      background: AppColors.surface,
      foreground: AppColors.textPrimary,
      border: AppColors.border,
    );
  }
}
