import 'package:flutter/widgets.dart';

import '../data/goods_api.dart';

/// 소장품 화면들에 [GoodsApi] 구현을 내려주는 InheritedWidget.
///
/// `MemoryConcertApiScope` 와 같은 방식이다. 앱이 맨 위에서 구현 하나를 만들어
/// 담고, 화면은 올리거나 받아 올 때 [of] 로 꺼낸다.
class GoodsApiScope extends InheritedWidget {
  const GoodsApiScope({super.key, required this.api, required super.child});

  final GoodsApi api;

  /// 구독이 아니라 읽기만 한다. 값이 바뀌지 않으므로 initState 에서도 부른다.
  static GoodsApi of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<GoodsApiScope>();
    assert(
      scope != null,
      'GoodsApiScope 가 위젯 트리 위에 없습니다. App 처럼 MaterialApp 을 '
      'GoodsApiScope 로 감싸세요.',
    );
    return scope!.api;
  }

  @override
  bool updateShouldNotify(GoodsApiScope oldWidget) => api != oldWidget.api;
}
