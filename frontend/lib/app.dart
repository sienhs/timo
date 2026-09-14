import 'package:flutter/material.dart';

import 'core/network/api_client.dart';
import 'core/network/auth_interceptor.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/http_auth_api.dart';
import 'features/auth/data/token_storage.dart';
import 'features/auth/state/auth_api_scope.dart';
import 'features/auth/state/auth_session.dart';
import 'features/auth/state/auth_session_scope.dart';
import 'features/booking/data/mock_booking_data.dart';
import 'features/booking/state/booking_controller.dart';
import 'features/booking/state/booking_scope.dart';
import 'features/home/data/home_api.dart';
import 'features/home/data/http_home_api.dart';
import 'features/home/state/home_api_scope.dart';
import 'routes/app_routes.dart';

class App extends StatefulWidget {
  const App({super.key, this.session, this.authApi, this.homeApi});

  /// 로그인 상태. main 이 기기 저장소에서 되살려 넘긴다. 안 넘기면(위젯 테스트)
  /// 메모리 저장소로 된 로그아웃 상태에서 시작한다.
  final AuthSession? session;

  /// 인증 API. 안 넘기면 진짜 서버 구현을 쓴다. 테스트는 목을 넣는다.
  final AuthApi? authApi;

  /// 홈·검색 화면이 쓰는 공연 API. 안 넘기면 진짜 서버 구현을 쓴다. 테스트는
  /// 목을 넣는다.
  final HomeApi? homeApi;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final AuthSession _session =
      widget.session ?? AuthSession(storage: InMemoryTokenStorage());

  /// 회원가입·로그인 화면들이 쓰는 인증 API. 앱에 하나만 두고 [AuthApiScope] 로
  /// 내려준다. 화면이 각자 만들면 서버 주소·로그 설정이 흩어지고, 테스트에서
  /// 목으로 갈아끼울 자리도 없어진다.
  late final AuthApi _authApi = widget.authApi ?? HttpAuthApi();

  /// 홈·검색 화면이 쓰는 공연 API. 인증 API 와 같은 이유로 앱에 하나만 두고
  /// [HomeApiScope] 로 내려준다.
  late final HomeApi _homeApi = widget.homeApi ?? HttpHomeApi();

  /// 로그인 상태면 서버 요청에 토큰을 붙이고, 401 이면 로그아웃시키는 인터셉터.
  /// 공유 dio 에 꽂으므로 이 위젯이 사라질 때 빼 준다(테스트가 App 을 여러 번
  /// 띄워도 인터셉터가 쌓이지 않게).
  late final _authInterceptor = AuthInterceptor(
    accessToken: () => _session.accessToken,
    onUnauthorized: _session.signOut,
  );

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
  void initState() {
    super.initState();
    // 맨 앞에 꽂아야 그 뒤의 로그 인터셉터가 Authorization 헤더까지 찍는다.
    ApiClient.dio.interceptors.insert(0, _authInterceptor);
  }

  @override
  void dispose() {
    ApiClient.dio.interceptors.remove(_authInterceptor);
    _bookingController.dispose();
    // 세션은 우리가 만든 것(테스트용 기본값)만 정리한다. main 이 넘긴 것은
    // 앱과 수명이 같아 따로 정리할 일이 없다.
    if (widget.session == null) _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthSessionScope(
      session: _session,
      child: AuthApiScope(
        api: _authApi,
        child: HomeApiScope(
          api: _homeApi,
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
        ),
      ),
    );
  }
}
