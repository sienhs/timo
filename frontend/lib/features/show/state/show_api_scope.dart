import 'package:flutter/widgets.dart';

import '../data/show_api.dart';

/// 공연 상세 화면에 [ShowApi] 구현을 내려주는 InheritedWidget.
/// 앱은 맨 위에서 구현을 하나 만들어 담고, 화면은 요청을 보낼 때 [of] 로 꺼내 쓴다.
class ShowApiScope extends InheritedWidget {
  const ShowApiScope({super.key, required this.api, required super.child});

  final ShowApi api;

  /// 요청을 보내는 자리에서 꺼낸다. 구독이 아니라 읽기만 하므로 리빌드가 걸리지
  /// 않고 `initState` 에서도 부를 수 있다.
  static ShowApi of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<ShowApiScope>();
    assert(
      scope != null,
      'ShowApiScope 가 위젯 트리 위에 없습니다. App 처럼 MaterialApp 을 '
      'ShowApiScope 로 감싸세요.',
    );
    return scope!.api;
  }

  @override
  bool updateShouldNotify(ShowApiScope oldWidget) => api != oldWidget.api;
}
