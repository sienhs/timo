import 'package:flutter/widgets.dart';

import '../data/booking_api.dart';

/// 예매 화면들에 [BookingApi] 구현을 내려주는 InheritedWidget. 앱이 켜져 있는
/// 동안 바뀌지 않는 구현 하나를 내려줄 뿐이라 평범한 InheritedWidget 으로 충분하다.
class BookingApiScope extends InheritedWidget {
  const BookingApiScope({super.key, required this.api, required super.child});

  final BookingApi api;

  /// 요청을 보내는 자리에서 꺼낸다. 구독이 아니라 읽기만 하므로 `initState`
  /// 에서도 부를 수 있다.
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
