import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/show_summary.dart';

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

/// 티켓 오픈 시각 뱃지. (예: `오늘 14:00 오픈`) 배경은 [AppColors.primaryPressed]
/// 다 — [AppColors.primary] 위 흰 글자는 대비 3.43:1 이라 작은 글자에는 못 쓴다.
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

/// 예매 상태 뱃지. (`예매중` · `오픈예정` · `예매 마감`) 어느 상태에 색을 주는지는
/// [HomeStrings.bookingOnSale] 주석에 적었다.
class BookingStatusBadge extends StatelessWidget {
  const BookingStatusBadge({super.key, required this.show, this.now});

  final ShowSummary show;

  /// 기준 시각. 테스트에서 마감 경계를 고정하려고 받는다.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    if (show.isBookableNow(now ?? DateTime.now())) {
      // 브랜드 그린 위 흰 글자. 작은 흰 글자에는 primary 의 3.43:1 이 모자라
      // [TicketOpenBadge] 처럼 눌림색을 쓴다.
      return const _PosterBadge(
        label: HomeStrings.bookingOnSale,
        background: AppColors.primaryPressed,
        foreground: AppColors.onPrimary,
      );
    }
    if (show.status == ShowSummary.upcomingStatus) {
      // 코랄 위에는 어두운 글자를 올린다. 흰 글자는 2.9:1 로 미달이고,
      // 어두운 글자는 6.2:1 이라 이 크기에도 충분하다.
      return const _PosterBadge(
        label: HomeStrings.bookingUpcoming,
        background: AppColors.accent,
        foreground: AppColors.textPrimary,
      );
    }
    // 매진·종료·취소도 여기로 온다. 어느 상태가 오더라도 "지금 살 수 있는가" 의
    // 답은 같다.
    return const _PosterBadge(
      label: HomeStrings.bookingClosed,
      background: AppColors.surface,
      foreground: AppColors.textSecondary,
      border: AppColors.border,
    );
  }
}
