import 'package:flutter/widgets.dart';

import '../data/favorite_store.dart';

/// 하트가 있는 화면들에 [FavoriteStore] 를 내려주는 InheritedNotifier. 저장소가
/// 알릴 때 [of] 로 읽은 화면이 함께 리빌드된다.
class FavoriteScope extends InheritedNotifier<FavoriteStore> {
  const FavoriteScope({
    super.key,
    required FavoriteStore store,
    required super.child,
  }) : super(notifier: store);

  /// 저장소가 알릴 때 같이 리빌드된다. build 안에서 찜 여부를 읽을 때 쓴다.
  static FavoriteStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<FavoriteScope>();
    assert(
      scope != null,
      'FavoriteScope 가 위젯 트리 위에 없습니다. App 처럼 MaterialApp 을 '
      'FavoriteScope 로 감싸세요.',
    );
    return scope!.notifier!;
  }

  /// 구독하지 않고 저장소만 꺼낸다. onTap 콜백처럼 쓰기만 하는 자리용.
  static FavoriteStore read(BuildContext context) {
    final store = context
        .getInheritedWidgetOfExactType<FavoriteScope>()
        ?.notifier;
    assert(store != null, 'FavoriteScope 가 위젯 트리 위에 없습니다');
    return store!;
  }
}
