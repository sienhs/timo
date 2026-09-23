import 'package:flutter/widgets.dart';

import 'booking_controller.dart';

/// 예매 플로우 전체에 [BookingController] 를 내려주는 InheritedNotifier. 공유할
/// 상태가 컨트롤러 하나뿐이라 provider 같은 패키지 없이 기본 위젯으로 충분하다.
class BookingScope extends InheritedNotifier<BookingController> {
  const BookingScope({
    super.key,
    required BookingController controller,
    required super.child,
  }) : super(notifier: controller);

  /// 컨트롤러가 알릴 때 호출한 위젯도 함께 리빌드된다. build 안에서 쓴다.
  static BookingController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<BookingScope>();
    assert(scope != null, 'BookingScope 가 위젯 트리 위에 없습니다');
    return scope!.notifier!;
  }

  /// 구독하지 않고 컨트롤러만 꺼낸다. onTap 콜백처럼 값을 읽어 쓰기만 하는
  /// 자리에서 이걸 쓰면 불필요한 리빌드가 생기지 않는다.
  static BookingController read(BuildContext context) {
    final controller = maybeRead(context);
    assert(controller != null, 'BookingScope 가 위젯 트리 위에 없습니다');
    return controller!;
  }

  /// 스코프가 없을 수도 있는 자리에서 쓴다. 결제 화면처럼 예매 흐름 밖에서
  /// 단독으로 열릴 수 있는 화면의 라우트가 쓴다. [read] 를 쓰면 스코프 없이
  /// 라우트만 띄우는 테스트가 깨진다.
  static BookingController? maybeRead(BuildContext context) =>
      context.getInheritedWidgetOfExactType<BookingScope>()?.notifier;
}
