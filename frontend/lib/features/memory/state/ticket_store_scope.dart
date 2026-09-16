import 'package:flutter/widgets.dart';

import '../data/ticket_store.dart';

/// 메모리 티켓 화면들에 [TicketStore] 를 내려주는 InheritedNotifier.
///
/// `BookingScope` 와 같은 방식이다. 저장소가 알릴 때([TicketStore] 의 저장·삭제)
/// [of] 로 읽은 화면이 함께 리빌드된다 — 제작이 백그라운드에서 끝나도 목록이
/// 따라오게 하는 것이 이 스코프의 유일한 일이다.
class TicketStoreScope extends InheritedNotifier<TicketStore> {
  const TicketStoreScope({
    super.key,
    required TicketStore store,
    required super.child,
  }) : super(notifier: store);

  /// 저장소가 알릴 때 같이 리빌드된다. build 안에서 목록을 읽을 때 쓴다.
  static TicketStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TicketStoreScope>();
    assert(scope != null, 'TicketStoreScope 가 위젯 트리 위에 없습니다');
    return scope!.notifier!;
  }

  /// 구독하지 않고 저장소만 꺼낸다. onTap 콜백처럼 쓰기만 하는 자리용.
  static TicketStore read(BuildContext context) {
    final store = context.getInheritedWidgetOfExactType<TicketStoreScope>()?.notifier;
    assert(store != null, 'TicketStoreScope 가 위젯 트리 위에 없습니다');
    return store!;
  }
}
