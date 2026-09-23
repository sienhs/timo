import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../routes/app_routes.dart';
import '../../auth/state/auth_session_scope.dart';
import '../../notification/push_notification_scope.dart';
import '../../notification/state/notification_api_scope.dart';
import '../constants.dart';
import 'my_page_top_bar.dart';

/// 안 읽은 알림이 있으면 종에 점을 찍고, 종을 누르면 알림함을 여는 상단 바.
///
/// [MyPageTopBar] 는 받은 값을 그리기만 한다. 개수를 서버에 묻고 알림함을 다녀온
/// 뒤 다시 묻는 일은 여기가 맡는다. 마이페이지와 충전 화면이 같은 상단 바를 써서
/// 두 화면이 이것을 함께 쓴다.
///
/// **되풀이해 묻지 않는다.** 화면에 들어올 때와 알림함에서 돌아왔을 때만 묻는다.
/// 그 사이에 앱이 켜진 채로 푸시가 오면, 서버가 푸시에 실어 보낸 개수로 바로
/// 맞춘다. 서버 규약이 그렇다 — 폴링하지 않고 푸시가 실시간 갱신을 맡는다.
///
/// 개수를 못 받아도 아무것도 알리지 않는다. 점이 안 찍힐 뿐이고, 알림함은 종을
/// 눌러 그대로 들어갈 수 있다. 상단 바에 실패 문구를 띄우면 정작 보러 온 화면을
/// 가린다.
class MyPageTopBarHost extends StatefulWidget {
  const MyPageTopBarHost({
    super.key,
    required this.onBackPressed,
    this.title = MyPageStrings.title,
  });

  final VoidCallback onBackPressed;
  final String title;

  @override
  State<MyPageTopBarHost> createState() => _MyPageTopBarHostState();
}

class _MyPageTopBarHostState extends State<MyPageTopBarHost> {
  int _unreadCount = 0;

  /// 이 화면에 들어와 한 번 물었는지. 다시 그려질 때마다 묻지 않으려고 둔다.
  bool _asked = false;

  /// 푸시로 오는 개수를 듣는 구독. 화면이 처음 뜰 때 한 번만 건다.
  StreamSubscription<int>? _pushedCounts;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pushedCounts ??= PushNotificationScope.maybeOf(
      context,
    )?.unreadCounts.listen(_onPushedCount);
    final isLoggedIn = AuthSessionScope.maybeOf(context)?.isLoggedIn ?? false;
    if (!isLoggedIn) {
      // 로그아웃하면 직전 회원의 개수가 남지 않게 지운다. 다시 로그인하면 아래
      // 조건이 다시 열려 새로 묻는다.
      if (_unreadCount != 0 || _asked) {
        setState(() {
          _unreadCount = 0;
          _asked = false;
        });
      }
      return;
    }
    if (_asked) return;
    _asked = true;
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    final api = NotificationApiScope.maybeOf(context);
    if (api == null) return;
    try {
      final count = await api.fetchUnreadCount();
      if (mounted) setState(() => _unreadCount = count);
    } on ApiException {
      // 위 설명대로 알리지 않는다.
    }
  }

  /// 앱이 켜진 채로 푸시가 왔을 때. 로그아웃 상태면 직전 회원 몫이 늦게 온
  /// 것이라 받지 않는다.
  void _onPushedCount(int count) {
    if (!mounted) return;
    if (!(AuthSessionScope.maybeRead(context)?.isLoggedIn ?? false)) return;
    setState(() => _unreadCount = count);
  }

  @override
  void dispose() {
    _pushedCounts?.cancel();
    super.dispose();
  }

  /// 알림함을 열고, 돌아오면 개수를 다시 받는다. 거기서 읽었으면 점이 사라져야
  /// 한다.
  Future<void> _openNotifications() async {
    await Navigator.pushNamed(context, AppRoutes.notifications);
    if (mounted) await _loadUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    return MyPageTopBar(
      title: widget.title,
      onBackPressed: widget.onBackPressed,
      onNotificationsPressed: _openNotifications,
      hasUnreadNotifications: _unreadCount > 0,
    );
  }
}
