import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 뒤로가기 · 제목 · 알림 입구. 마이페이지는 셸의 탭 본문이라 AppBar 를 둘
/// Scaffold 가 없어 본문 위젯으로 그린다.
///
/// [hasUnreadNotifications] 가 참이면 알림 아이콘에 점을 찍는다. 알림 API 가
/// 아직 없어 지금은 화면이 늘 거짓을 넘긴다.
///
/// 충전 화면도 같은 상단 바를 쓴다(시안이 같은 모양이다). 제목만 다르므로
/// [title] 로 받고 기본값은 마이페이지다.
class MyPageTopBar extends StatelessWidget {
  const MyPageTopBar({
    super.key,
    required this.onBackPressed,
    required this.onNotificationsPressed,
    this.title = MyPageStrings.title,
    this.hasUnreadNotifications = false,
  });

  final String title;

  final VoidCallback onBackPressed;
  final VoidCallback onNotificationsPressed;
  final bool hasUnreadNotifications;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MyPageMetrics.topBarHeight,
      child: Row(
        children: [
          IconButton(
            onPressed: onBackPressed,
            tooltip: MyPageStrings.back,
            iconSize: MyPageMetrics.topBarIconSize,
            color: AppColors.textPrimary,
            icon: const Icon(Icons.arrow_back),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            onPressed: onNotificationsPressed,
            tooltip: MyPageStrings.notifications,
            iconSize: MyPageMetrics.topBarIconSize,
            color: AppColors.textPrimary,
            icon: _BellIcon(hasUnread: hasUnreadNotifications),
          ),
        ],
      ),
    );
  }
}

class _BellIcon extends StatelessWidget {
  const _BellIcon({required this.hasUnread});

  final bool hasUnread;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_outlined),
        if (hasUnread)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: MyPageMetrics.unreadDotSize,
              height: MyPageMetrics.unreadDotSize,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
