import 'package:flutter/widgets.dart';

import '../data/ticket_api.dart';

/// 내 티켓 화면들에 [TicketApi] 구현을 내려주는 InheritedWidget. 앱이 맨 위에서
/// 구현 하나를 담고 화면은 [of] 로 꺼낸다. 홈의 `HomeApiScope` 와 같은 방식이다.
class TicketApiScope extends InheritedWidget {
  const TicketApiScope({super.key, required this.api, required super.child});

  final TicketApi api;

  /// 요청을 보내는 자리에서 꺼낸다. 구독이 아니라 읽기만 하므로(값이 안 바뀐다)
  /// `initState` 에서도 부를 수 있다.
  static TicketApi of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<TicketApiScope>();
    assert(
      scope != null,
      'TicketApiScope 가 위젯 트리 위에 없습니다. App 처럼 MaterialApp 을 '
      'TicketApiScope 로 감싸세요.',
    );
    return scope!.api;
  }

  @override
  bool updateShouldNotify(TicketApiScope oldWidget) => api != oldWidget.api;
}
