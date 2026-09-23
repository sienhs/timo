import 'package:flutter/widgets.dart';

import 'push_notification_service.dart';

/// 화면에 [PushNotifications] 를 내려주는 InheritedWidget. 마이페이지(로그아웃
/// 때 기기 해제)와 로딩 화면(알림으로 켜졌는지 확인)이 쓴다. [maybeOf] 만 두고
/// 없을 때 단언하지 않는다 — 두 화면 모두 스코프 없이 띄우는 테스트가 있다.
class PushNotificationScope extends InheritedWidget {
  const PushNotificationScope({
    super.key,
    required this.push,
    required super.child,
  });

  final PushNotifications push;

  /// 쓰기만 하는 자리에서 꺼낸다. 구독이 아니라 읽기만 한다. 스코프가 위에
  /// 없으면 null 이고, 부르는 쪽은 그 일을 건너뛴다.
  static PushNotifications? maybeOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<PushNotificationScope>()?.push;
  }

  @override
  bool updateShouldNotify(PushNotificationScope oldWidget) =>
      push != oldWidget.push;
}
