import 'package:flutter/material.dart';

import '../features/booking/screens/seat_selection_screen.dart';
import '../features/booking/screens/zone_selection_screen.dart';
import '../features/booking/state/ticket_order_adapter.dart';
import '../features/home/screens/home_screen.dart';
import '../features/payment/screens/payment_complete_screen.dart';
import '../features/payment/screens/payment_screen.dart';

/// 화면 라우트 등록부.
/// 새 화면을 만들면 1) 이름 상수 추가, 2) routes 맵에 builder 등록.
/// 이동은 Navigator.pushNamed(context, AppRoutes.xxx) 사용.
class AppRoutes {
  AppRoutes._();

  static const home = '/';

  /// 구역 배치도(좌석 선택 시작)
  static const zoneSelection = '/booking/zones';

  /// 구역 하나의 좌석 배치도. 구역 id 를 arguments 로 받는다.
  static const seatSelection = '/booking/seats';

  static const payment = '/payment';
  static const paymentComplete = '/payment/complete';

  static final Map<String, WidgetBuilder> routes = {
    home: (_) => const HomeScreen(),
    zoneSelection: (_) => const ZoneSelectionScreen(),
    // 인자를 받는 화면은 여기서 한 번만 꺼내 타입을 맞춘다. 화면 위젯이
    // ModalRoute 를 직접 뒤지지 않게 해서 단독 테스트가 가능하다.
    seatSelection: (context) => SeatSelectionScreen(
          zoneId: ModalRoute.of(context)!.settings.arguments as String,
        ),
    // 고른 좌석으로 주문을 만들어 넘긴다. 이 연결이 없으면 어떤 좌석을 골라도
    // 결제 화면에 더미 좌석(A구역 9열 6번)이 찍힌다. 예매 흐름을 거치지 않고
    // 열린 경우는 ticketOrderOrSample 이 더미로 대체한다.
    payment: (context) => PaymentScreen(order: ticketOrderOrSample(context)),
    paymentComplete: (context) =>
        PaymentCompleteScreen(order: ticketOrderOrSample(context)),
  };
}
