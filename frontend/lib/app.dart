import 'package:flutter/material.dart';

import 'core/network/api_client.dart';
import 'core/network/api_exception.dart';
import 'core/network/auth_interceptor.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/http_auth_api.dart';
import 'features/auth/data/token_storage.dart';
import 'features/auth/state/auth_api_scope.dart';
import 'features/auth/state/auth_session.dart';
import 'features/auth/state/auth_session_scope.dart';
import 'features/booking/data/booking_api.dart';
import 'features/booking/data/http_booking_api.dart';
import 'features/booking/data/mock_booking_data.dart';
import 'features/booking/state/booking_api_scope.dart';
import 'features/booking/state/booking_controller.dart';
import 'features/booking/state/booking_scope.dart';
import 'features/home/data/home_api.dart';
import 'features/home/data/http_home_api.dart';
import 'features/home/data/recent_search_store.dart';
import 'features/home/state/home_api_scope.dart';
import 'features/home/state/recent_search_scope.dart';
import 'features/mypage/data/http_my_page_api.dart';
import 'features/mypage/data/my_page_api.dart';
import 'features/mypage/state/my_page_api_scope.dart';
import 'features/show/data/http_show_api.dart';
import 'features/show/data/show_api.dart';
import 'features/show/state/show_api_scope.dart';
import 'features/ticket/data/http_ticket_api.dart';
import 'features/ticket/data/mock_ticket_api.dart';
import 'features/ticket/data/ticket_api.dart';
import 'features/ticket/state/ticket_api_scope.dart';
import 'routes/app_routes.dart';

class App extends StatefulWidget {
  const App({
    super.key,
    this.session,
    this.authApi,
    this.homeApi,
    this.myPageApi,
    this.ticketApi,
    this.bookingApi,
    this.recentSearchStore,
    this.showApi,
  });

  /// 로그인 상태. main 이 기기 저장소에서 되살려 넘긴다. 안 넘기면(위젯 테스트)
  /// 메모리 저장소로 된 로그아웃 상태에서 시작한다.
  final AuthSession? session;

  /// 인증 API. 안 넘기면 진짜 서버 구현을 쓴다. 테스트는 목을 넣는다.
  final AuthApi? authApi;

  /// 홈·검색 화면이 쓰는 공연 API. 안 넘기면 진짜 서버 구현을 쓴다. 테스트는
  /// 목을 넣는다.
  final HomeApi? homeApi;

  /// 마이페이지가 쓰는 회원·지갑 API. 안 넘기면 진짜 서버 구현을 쓴다.
  final MyPageApi? myPageApi;

  /// 내 티켓 화면이 쓰는 API. 안 넘기면 [_ticketApiKind] 가 고른다.
  final TicketApi? ticketApi;

  /// 예매(구역·좌석·선점) API. 안 넘기면 진짜 서버 구현을 쓴다.
  final BookingApi? bookingApi;

  /// 검색 화면의 최근 검색어 저장소. main 이 기기 저장소 구현을 넘긴다. 안
  /// 넘기면(위젯 테스트) 메모리 구현이라 앱을 끄면 사라진다.
  final RecentSearchStore? recentSearchStore;

  /// 공연 상세 API. 안 넘기면 진짜 서버 구현을 쓴다. 테스트는 목을 넣는다.
  final ShowApi? showApi;

  @override
  State<App> createState() => _AppState();
}

/// 내 티켓 화면이 어느 [TicketApi] 를 쓸지 고르는 실행 인자.
///
/// ```bash
/// flutter run --dart-define=TICKET_API=mock    # 시안 데이터로. 백엔드 불필요
/// flutter run                                   # 기본값. 실제 서버(v1)
/// ```
///
/// 홈·인증에는 없는 장치다. 티켓은 서버로 만들 수 없는 화면이 있다 — 앱이
/// 모르는 주문 상태 카드(`mock-states`)와 시안 그대로의 목록(예정 2 · 지난 2).
/// 이 인자가 없으면 그걸 눈으로 볼 방법이 코드를 고쳤다 되돌리는 것뿐이다.
const _ticketApiKind = String.fromEnvironment('TICKET_API');

/// 실행 인자에 맞는 구현. 모르는 값이면 실제 서버로 간다.
TicketApi _ticketApiFor(String kind) => switch (kind) {
  'mock' => MockTicketApi(),
  'mock-states' => MockTicketApi(scenario: TicketMockScenario.states),
  'mock-empty' => MockTicketApi(scenario: TicketMockScenario.empty),
  'mock-error' => MockTicketApi(scenario: TicketMockScenario.error),
  _ => HttpTicketApi(),
};

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

  /// 마이페이지가 쓰는 회원·지갑 API. 위 둘과 같은 이유로 앱에 하나만 둔다.
  late final MyPageApi _myPageApi = widget.myPageApi ?? HttpMyPageApi();

  /// 내 티켓 화면이 쓰는 API. 위 셋과 같은 이유로 앱에 하나만 두고
  /// [TicketApiScope] 로 내려준다.
  late final TicketApi _ticketApi =
      widget.ticketApi ?? _ticketApiFor(_ticketApiKind);

  /// 공연 상세 화면이 쓰는 API. 위 넷과 같은 이유로 앱에 하나만 두고
  /// [ShowApiScope] 로 내려준다.
  late final ShowApi _showApi = widget.showApi ?? HttpShowApi();

  /// 로그인 상태면 서버 요청에 토큰을 붙이고, 만료되면 재발급받아 요청을
  /// 이어가는 인터셉터. 공유 dio 에 꽂으므로 이 위젯이 사라질 때 빼 준다
  /// (테스트가 App 을 여러 번 띄워도 인터셉터가 쌓이지 않게).
  late final _authInterceptor = AuthInterceptor(
    dio: ApiClient.dio,
    accessToken: () => _session.accessToken,
    memberId: () => _session.memberId,
    onUnauthorized: _session.signOut,
    reissue: _reissueAccessToken,
  );

  /// 리프레시 토큰으로 새 액세스 토큰을 받아 세션에 넣는다. 성공하면 참.
  ///
  /// 인터셉터가 부른다. 이 조립을 세션이나 인터셉터 안에 두지 않은 이유는
  /// 로그아웃 때와 같다 — 세션은 네트워크를 모르고, 인터셉터(공통 모듈)는 인증
  /// 기능 폴더를 모른다. 둘을 아는 곳은 앱을 조립하는 여기뿐이다.
  Future<bool> _reissueAccessToken() async {
    final refreshToken = _session.refreshToken;
    if (refreshToken == null) return false;

    try {
      await _session.renewAccessToken(await _authApi.reissue(refreshToken));
    } on ApiException {
      // 서버가 거절했거나 닿지 못했다. 어느 쪽이든 재시도할 토큰이 없다.
      return false;
    }

    // 다녀오는 사이 사용자가 로그아웃했으면 세션이 새 토큰을 받지 않았다.
    // 그때는 실패로 쳐서 원래 요청을 되살리지 않는다.
    return _session.isLoggedIn;
  }

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
  );

  /// 예매 화면이 쓰는 구역·좌석 API. 위 넷과 같은 이유로 앱에 하나만 두고
  /// [BookingApiScope] 로 내려준다.
  late final BookingApi _bookingApi = widget.bookingApi ?? HttpBookingApi();

  /// 최근 검색어 저장소. API 들과 같은 이유로 앱에 하나만 두고
  /// [RecentSearchScope] 로 내려준다.
  late final RecentSearchStore _recentSearchStore =
      widget.recentSearchStore ?? InMemoryRecentSearchStore();

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
          child: MyPageApiScope(
            api: _myPageApi,
            child: TicketApiScope(
              api: _ticketApi,
              child: ShowApiScope(
                api: _showApi,
                child: BookingApiScope(
                  api: _bookingApi,
                  child: BookingScope(
                    controller: _bookingController,
                    child: RecentSearchScope(
                      store: _recentSearchStore,
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
