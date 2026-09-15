import 'package:flutter/widgets.dart';

import '../data/recent_search_store.dart';

/// 검색 화면에 [RecentSearchStore] 구현을 내려주는 InheritedWidget.
///
/// 앱은 맨 위에서 진짜 구현을 하나 만들어 여기에 담고, 화면은 [of] 로 꺼내
/// 쓴다. [HomeApiScope] 와 같은 방식이다 — 구현 하나를 내려줄 뿐이라 구독은
/// 하지 않고 읽기만 한다.
class RecentSearchScope extends InheritedWidget {
  const RecentSearchScope({
    super.key,
    required this.store,
    required super.child,
  });

  final RecentSearchStore store;

  static RecentSearchStore of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<RecentSearchScope>();
    assert(
      scope != null,
      'RecentSearchScope 가 위젯 트리 위에 없습니다. App 처럼 MaterialApp 을 '
      'RecentSearchScope 로 감싸세요.',
    );
    return scope!.store;
  }

  @override
  bool updateShouldNotify(RecentSearchScope oldWidget) =>
      store != oldWidget.store;
}
