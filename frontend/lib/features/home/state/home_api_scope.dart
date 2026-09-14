import 'package:flutter/widgets.dart';

import '../data/home_api.dart';

/// 홈·검색 화면에 [HomeApi] 구현을 내려주는 InheritedWidget.
///
/// 앱은 맨 위에서 진짜 구현(HttpHomeApi)을 하나 만들어 여기에 담고, 화면은
/// 요청을 보낼 때 [of] 로 꺼내 쓴다. 인증의 `AuthApiScope` 와 같은 방식이다.
///
/// 앱이 켜져 있는 동안 바뀌지 않는 구현 하나를 내려줄 뿐이라 평범한
/// InheritedWidget 으로 충분하다.
class HomeApiScope extends InheritedWidget {
  const HomeApiScope({super.key, required this.api, required super.child});

  final HomeApi api;

  /// 요청을 보내는 자리에서 꺼낸다.
  ///
  /// 구독(dependOn…)이 아니라 읽기만 한다. 값이 바뀌지 않으므로 리빌드를
  /// 걸어 둘 이유가 없다. 그래서 `initState` 에서도 부를 수 있다.
  static HomeApi of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<HomeApiScope>();
    assert(
      scope != null,
      'HomeApiScope 가 위젯 트리 위에 없습니다. App 처럼 MaterialApp 을 '
      'HomeApiScope 로 감싸세요.',
    );
    return scope!.api;
  }

  @override
  bool updateShouldNotify(HomeApiScope oldWidget) => api != oldWidget.api;
}
