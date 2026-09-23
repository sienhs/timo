import 'package:flutter/widgets.dart';

import '../data/notification_api.dart';

/// 알림함 화면에 [NotificationApi] 구현을 내려주는 InheritedWidget. 앱은 맨 위에서
/// 진짜 구현을 담고, 화면은 [of] 로 꺼내 쓴다.
class NotificationApiScope extends InheritedWidget {
  const NotificationApiScope({
    super.key,
    required this.api,
    required super.child,
  });

  final NotificationApi api;

  /// 요청을 보내는 자리에서 꺼낸다. 구독이 아니라 읽기만 하므로 `initState`
  /// 에서도 부를 수 있다.
  static NotificationApi of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<NotificationApiScope>();
    assert(
      scope != null,
      'NotificationApiScope 가 위젯 트리 위에 없습니다. App 처럼 MaterialApp 을 '
      'NotificationApiScope 로 감싸세요.',
    );
    return scope!.api;
  }

  /// 없으면 null. 알림함이 아닌 화면이 곁다리로 알림을 물을 때 쓴다 — 마이페이지
  /// 상단의 안 읽음 점이 그렇다. 그 화면들은 스코프 없이 띄우는 테스트가 있고,
  /// 점이 안 찍히는 것은 화면이 못 뜨는 것과 달리 넘어갈 만한 일이다.
  static NotificationApi? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<NotificationApiScope>()?.api;

  @override
  bool updateShouldNotify(NotificationApiScope oldWidget) =>
      api != oldWidget.api;
}
