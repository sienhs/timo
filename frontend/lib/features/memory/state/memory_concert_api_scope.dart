import 'package:flutter/widgets.dart';

import '../data/memory_concert_api.dart';

/// 메모리 티켓 화면들에 [MemoryConcertApi] 구현을 내려주는 InheritedWidget.
///
/// `HomeApiScope`·`ShowApiScope` 와 같은 방식이다. 앱이 맨 위에서 구현 하나를
/// 만들어 담고, 화면은 요청을 보낼 때 [of] 로 꺼낸다.
class MemoryConcertApiScope extends InheritedWidget {
  const MemoryConcertApiScope({
    super.key,
    required this.api,
    required super.child,
  });

  final MemoryConcertApi api;

  /// 구독이 아니라 읽기만 한다. 값이 바뀌지 않으므로 initState 에서도 부른다.
  static MemoryConcertApi of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<MemoryConcertApiScope>();
    assert(
      scope != null,
      'MemoryConcertApiScope 가 위젯 트리 위에 없습니다. App 처럼 MaterialApp 을 '
      'MemoryConcertApiScope 로 감싸세요.',
    );
    return scope!.api;
  }

  @override
  bool updateShouldNotify(MemoryConcertApiScope oldWidget) =>
      api != oldWidget.api;
}
