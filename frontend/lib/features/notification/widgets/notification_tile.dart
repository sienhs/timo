import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/app_notification.dart';
import '../relative_time.dart';

/// 알림함 목록의 알림 한 건.
///
/// 읽음과 안 읽음을 **글자 굵기와 점** 두 가지로 나눈다. '읽음'·'안 읽음' 같은
/// 글자는 쓰지 않는다. 두 가지를 같이 쓰는 것은 점이 색으로만 구분되기 때문이다 —
/// 색을 가려내기 어려운 사람에게는 점이 보이지 않지만 굵기는 보인다.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
    this.now,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  /// 시각 표기의 기준. 테스트에서 시계를 고정하려고 받는다.
  final DateTime? now;

  /// 목록에 그릴 본문. 여러 줄로 온 알림은 **첫 줄만** 쓴다.
  ///
  /// 양도 매물 알림은 요약 아래에 `· 공연명` 목록이 붙어 네 줄까지 온다. 목록에서
  /// 두 줄만 보이면 공연 하나가 점과 함께 덩그러니 남아 어색하다. 첫 줄이 그 자체로
  /// 요약이라(서버가 그렇게 만든다) 빼도 뜻이 통하고, 눌러 들어가면 마켓에서 전부
  /// 볼 수 있다.
  ///
  /// 그래도 두 줄까지 그린다. 공연명이 긴 알림은 한 줄로 안 들어가 접혀야 한다.
  String get _summaryLine {
    final lineBreak = notification.body.indexOf('\n');
    return lineBreak == -1
        ? notification.body
        : notification.body.substring(0, lineBreak);
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.read;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: NotificationMetrics.horizontalPadding,
          vertical: NotificationMetrics.tileVerticalPadding,
        ),
        child: Row(
          // 본문이 두 줄이어도 점과 첫 줄이 맞도록 위를 기준으로 세운다.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: NotificationMetrics.unreadDotColumnWidth,
              child: isUnread ? const _UnreadDot() : null,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _summaryLine,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: NotificationMetrics.bodyFontSize,
                      height: NotificationMetrics.bodyLineHeight,
                      fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                      color: isUnread
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: NotificationMetrics.bodyToTimeGap),
                  Text(
                    relativeTime(notification.createdAt, now: now),
                    style: const TextStyle(
                      fontSize: NotificationMetrics.timeFontSize,
                      color: AppColors.textDisabled,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 안 읽음 표시. 본문 첫 줄의 한가운데에 맞춰 내린다.
///
/// 색은 마이페이지 종 위의 배지(`MyPageTopBar`)와 같은 [AppColors.accent] 다.
/// 같은 "안 읽음" 을 두 색으로 칠하면, 빨간 점을 보고 들어온 사람이 안에서 다른
/// 색 점을 보게 된다.
class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: NotificationMetrics.unreadDotTopInset),
      child: SizedBox(
        width: NotificationMetrics.unreadDotSize,
        height: NotificationMetrics.unreadDotSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
