import 'package:flutter/widgets.dart';

import '../data/concert_api.dart';

/// 공연 선택 화면에 [ConcertApi] 구현을 내려주는 InheritedWidget.
///
/// 구독이 아니라 읽기만 하므로 `initState` 에서도 부를 수 있다. 스캔·인증의
/// 같은 이름 클래스와 역할이 같다.
class ConcertApiScope extends InheritedWidget {
  const ConcertApiScope({super.key, required this.api, required super.child});

  final ConcertApi api;

  static ConcertApi of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<ConcertApiScope>();
    assert(scope != null, 'ConcertApiScope 가 위젯 트리 위에 없습니다.');
    return scope!.api;
  }

  @override
  bool updateShouldNotify(ConcertApiScope oldWidget) => api != oldWidget.api;
}
