import 'package:flutter/widgets.dart';

import '../data/resale_api.dart';

/// 양도마켓 화면들에 [ResaleApi] 구현을 내려주는 InheritedWidget.
///
/// 앱은 맨 위에서 구현을 하나 만들어 여기에 담고, 화면은 요청을 보낼 때 [of] 로
/// 꺼내 쓴다. 마이페이지의 `MyPageApiScope` 와 같은 방식이다.
class ResaleApiScope extends InheritedWidget {
  const ResaleApiScope({super.key, required this.api, required super.child});

  final ResaleApi api;

  /// 요청을 보내는 자리에서 꺼낸다. 구독이 아니라 읽기만 하므로 `initState`
  /// 에서도 부를 수 있다.
  static ResaleApi of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<ResaleApiScope>();
    assert(
      scope != null,
      'ResaleApiScope 가 위젯 트리 위에 없습니다. App 처럼 MaterialApp 을 '
      'ResaleApiScope 로 감싸세요.',
    );
    return scope!.api;
  }

  @override
  bool updateShouldNotify(ResaleApiScope oldWidget) => api != oldWidget.api;
}
