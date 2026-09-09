import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/data/http_auth_api.dart';
import 'features/auth/state/auth_api_scope.dart';
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
  /// 회원가입 화면들이 쓰는 진짜 서버 구현. 앱에 하나만 두고 [AuthApiScope] 로
  /// 내려준다. 화면이 각자 만들면 서버 주소·로그 설정이 흩어지고, 테스트에서
  /// 목으로 갈아끼울 자리도 없어진다. 로그인 화면은 백엔드 API 가 아직 없어
  /// 여전히 목을 쓴다.
  late final _authApi = HttpAuthApi();

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
    return AuthApiScope(
      api: _authApi,
      child: BookingScope(
        controller: _bookingController,
        child: MaterialApp(
          title: 'TIMO',
          theme: AppTheme.light,
          // 하단 바를 두른 홈 셸이 생겼으므로 여기서 시작한다.
          // 예매 흐름은 홈의 '예매 화면 보기' 로 들어간다.
          initialRoute: AppRoutes.home,
          routes: AppRoutes.routes,
        ),
      ),
    );
  }
}
