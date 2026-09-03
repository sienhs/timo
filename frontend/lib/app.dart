import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/booking/data/mock_booking_data.dart';
import 'features/booking/state/booking_controller.dart';
import 'features/booking/state/booking_scope.dart';
import 'routes/app_routes.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  /// 예매 플로우는 좌석 선택 → 결제 → 완료가 서로 다른 라우트인데 고른
  /// 좌석은 그 경계를 넘어 유지돼야 한다. 그래서 컨트롤러를 라우트보다
  /// 위에서 만들어 [BookingScope] 로 내려준다. 결제 라우트가 이 컨트롤러를
  /// 읽어 TicketOrder 를 만든다.
  ///
  /// [BookingScope] 가 MaterialApp 을 감싸도 MaterialApp 이 매번 리빌드되지는
  /// 않는다. InheritedNotifier 는 알림 시 child 위젯 인스턴스를 그대로
  /// 돌려주므로 Element.updateChild 가 동일 위젯을 보고 조기 반환한다.
  ///
  /// 실제 앱이라면 '예매 시작' 시점에 만들고 완료·이탈 시 버리는 게 맞다.
  late final _bookingController = BookingController(
    performance: MockBookingData.performance,
    zones: MockBookingData.zones,
    seatRowsByZone: MockBookingData.seatRowsByZone,
  );

  @override
  void dispose() {
    _bookingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BookingScope(
      controller: _bookingController,
      child: MaterialApp(
        title: 'TIMO',
        theme: AppTheme.light,
        // 좌석 선택 → 결제 → 완료가 이어졌으므로 흐름의 처음에서 시작한다.
        // 홈 화면이 준비되면 AppRoutes.home 으로 되돌린다.
        initialRoute: AppRoutes.zoneSelection,
        routes: AppRoutes.routes,
      ),
    );
  }
}
