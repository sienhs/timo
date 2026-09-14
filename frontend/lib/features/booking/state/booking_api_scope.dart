import 'package:flutter/widgets.dart';

import '../data/booking_api.dart';

/// 예매 화면들에 [BookingApi] 구현을 내려주는 InheritedWidget.
///
/// 앱은 맨 위에서 구현을 하나 만들어 여기에 담고, 화면은 요청을 보낼 때 [of]
/// 로 꺼내 쓴다. 홈의 `HomeApiScope`, 내 티켓의 `TicketApiScope` 와 같다.
///
/// 앱이 켜져 있는 동안 바뀌지 않는 구현 하나를 내려줄 뿐이라 평범한
/// InheritedWidget 으로 충분하다.
class BookingApiScope extends InheritedWidget {
  const BookingApiScope({super.key, required this.api, required super.child});

  final BookingApi api;

  /// 요청을 보내는 자리에서 꺼낸다.
  ///
  /// 구독(dependOn…)이 아니라 읽기만 한다. 값이 바뀌지 않으므로 리빌드를
  /// 걸어 둘 이유가 없다. 그래서 `initState` 에서도 부를 수 있다.
  static BookingApi of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<BookingApiScope>();
    assert(
      scope != null,
      'BookingApiScope 가 위젯 트리 위에 없습니다. App 처럼 MaterialApp 을 '
      'BookingApiScope 로 감싸세요.',
    );
    return scope!.api;
  }

  @override
  bool updateShouldNotify(BookingApiScope oldWidget) => api != oldWidget.api;
}
