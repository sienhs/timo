import 'dart:async';

import 'package:flutter/material.dart';

import 'core/network/api_client.dart';
import 'core/network/api_exception.dart';
import 'core/network/auth_interceptor.dart';
import 'core/theme/app_theme.dart';
import 'features/alarm/data/alarm_api.dart';
import 'features/alarm/data/http_alarm_api.dart';
import 'features/alarm/state/alarm_api_scope.dart';
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
import 'features/favorite/data/favorite_api.dart';
import 'features/favorite/data/favorite_artist_store.dart';
import 'features/favorite/data/favorite_store.dart';
import 'features/favorite/data/http_favorite_api.dart';
import 'features/favorite/state/favorite_scope.dart';
import 'features/home/data/home_api.dart';
import 'features/home/data/http_home_api.dart';
import 'features/home/data/recent_search_store.dart';
import 'features/home/state/home_api_scope.dart';
import 'features/home/state/recent_search_scope.dart';
import 'features/memory/data/goods_api.dart';
import 'features/memory/data/memory_concert_api.dart';
import 'features/memory/data/ticket_store.dart';
import 'features/memory/data/tilt_setting.dart';
import 'features/memory/data/viewer_guide_setting.dart';
import 'features/memory/motion/ambient_motion.dart';
import 'features/memory/motion/motion_tokens.dart';
import 'features/memory/state/creation_job.dart';
import 'features/memory/state/creation_job_scope.dart';
import 'features/memory/state/goods_api_scope.dart';
import 'features/memory/state/memory_concert_api_scope.dart';
import 'features/memory/state/ticket_store_scope.dart';
import 'features/memory/state/tilt_setting_scope.dart';
import 'features/memory/state/viewer_guide_scope.dart';
import 'features/memory/widgets/creation_notification_host.dart';
import 'features/mypage/data/http_my_page_api.dart';
import 'features/mypage/data/my_page_api.dart';
import 'features/mypage/state/my_page_api_scope.dart';
import 'features/notification/data/http_notification_api.dart';
import 'features/notification/data/mock_notification_api.dart';
import 'features/notification/data/notification_api.dart';
import 'features/notification/push_notification_scope.dart';
import 'features/notification/push_notification_service.dart';
import 'features/notification/state/notification_api_scope.dart';
import 'features/resale/data/http_resale_api.dart';
import 'features/resale/data/mock_resale_api.dart';
import 'features/resale/data/resale_api.dart';
import 'features/resale/state/resale_api_scope.dart';
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
    this.initialRoute = AppRoutes.splash,
    this.session,
    this.authApi,
    this.homeApi,
    this.myPageApi,
    this.ticketApi,
    this.bookingApi,
    this.recentSearchStore,
    this.favoriteStore,
    this.favoriteApi,
    this.favoriteArtistStore,
    this.showApi,
    this.ticketStore,
    this.tiltSettingStore,
    this.viewerGuideStore,
    this.memoryConcertApi,
    this.goodsApi,
    this.resaleApi,
    this.push,
    this.navigatorKey,
    this.notificationApi,
    this.alarmApi,
  });

  /// 처음 띄울 화면. 앱은 로딩 화면에서 시작해 홈으로 넘어간다. 테스트는 보고
  /// 싶은 화면을 바로 넘겨 로딩(2.5초)을 건너뛴다.
  final String initialRoute;

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

  /// 찜 목록 저장소. 통째로 넘기면 [favoriteApi]·[favoriteArtistStore] 는
  /// 쓰이지 않는다. 저장소를 직접 세워 넣는 테스트를 위해 남겨 둔다.
  final FavoriteStore? favoriteStore;

  /// 공연 찜 API. 안 넘기면 진짜 서버 구현을 쓴다. 테스트는 목을 넣는다.
  final FavoriteApi? favoriteApi;

  /// 아티스트 찜을 남길 기기 저장소. main 이 기기 설정 저장소 구현을 넘긴다.
  /// 안 넘기면(위젯 테스트) 메모리 구현이라 앱을 끄면 사라진다.
  final FavoriteArtistStore? favoriteArtistStore;

  /// 공연 상세 API. 안 넘기면 진짜 서버 구현을 쓴다. 테스트는 목을 넣는다.
  final ShowApi? showApi;

  /// 소장품(메모리 티켓) 저장소. main 이 기기 저장소 구현을 넘긴다. 안 넘기면
  /// (위젯 테스트, 또는 기기 저장소를 못 연 실행) 앱을 끄면 사라지는 구현으로
  /// 시작한다.
  final TicketStore? ticketStore;

  /// 기울임 효과를 켤지 말지를 남길 기기 저장소. main 이 기기 설정 저장소
  /// 구현을 넘긴다. 안 넘기면(위젯 테스트) 앱을 끄면 사라진다.
  final TiltSettingStore? tiltSettingStore;

  /// 소장품 조작법 안내를 봤는지를 남길 기기 저장소. main 이 기기 설정 저장소
  /// 구현을 넘긴다. 안 넘기면(위젯 테스트) 앱을 끄면 사라진다.
  final ViewerGuideStore? viewerGuideStore;

  /// 소장품을 만들 수 있는 공연 카탈로그 API. 안 넘기면 진짜 서버 구현을
  /// 쓴다. 테스트는 목을 넣는다.
  final MemoryConcertApi? memoryConcertApi;

  /// 소장품을 올리고 받아 오는 API. 안 넘기면 진짜 서버 구현을 쓴다. 테스트는
  /// 목을 넣는다 — 위젯 테스트가 확정을 눌러도 서버로 나가지 않는다.
  final GoodsApi? goodsApi;

  /// 양도마켓 화면이 쓰는 API. 안 넘기면 [_resaleApiKind] 가 고른다.
  final ResaleApi? resaleApi;

  /// 화면이 푸시 쪽에 부탁하는 것들(로그아웃 시 기기 해제, 알림으로 켜졌는지).
  /// main 이 푸시 서비스를 넘긴다. 안 넘기면(위젯 테스트) 아무것도 하지 않는
  /// 구현을 쓴다 — 진짜 구현은 만들 때 Firebase 를 건드려 테스트에서 못 만든다.
  final PushNotifications? push;

  /// 화면 전환 열쇠. 알림을 눌렀을 때 푸시 쪽도 같은 것으로 화면을 바꿔야 해서
  /// main 이 하나 만들어 앱과 푸시 양쪽에 준다. 안 넘기면 앱이 혼자 만들어 쓴다.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// 알림함 화면이 쓰는 API. 안 넘기면 [_notificationApiKind] 가 고른다.
  final NotificationApi? notificationApi;

  /// 공연 상세의 알림 신청 버튼이 쓰는 API. 안 넘기면 진짜 서버 구현을 쓴다.
  /// 테스트는 목을 넣는다.
  final AlarmApi? alarmApi;

  @override
  State<App> createState() => _AppState();
}

/// 내 티켓 화면이 어느 [TicketApi] 를 쓸지 고르는 실행 인자. 기본은 실제 서버,
/// `--dart-define=TICKET_API=mock` 이면 시안 데이터라 백엔드 없이 볼 수 있다.
/// 서버로는 만들 수 없는 상태 카드(`mock-states`)를 눈으로 볼 길을 남긴다.
const _ticketApiKind = String.fromEnvironment('TICKET_API');

/// 실행 인자에 맞는 구현. 모르는 값이면 실제 서버로 간다.
TicketApi _ticketApiFor(String kind) => switch (kind) {
  'mock' => MockTicketApi(),
  'mock-states' => MockTicketApi(scenario: TicketMockScenario.states),
  'mock-empty' => MockTicketApi(scenario: TicketMockScenario.empty),
  'mock-error' => MockTicketApi(scenario: TicketMockScenario.error),
  _ => HttpTicketApi(),
};

/// 알림함이 어느 [NotificationApi] 를 쓸지 고르는 실행 인자. 기본은 실제 서버,
/// `--dart-define=NOTIFICATION_API=mock` 이면 시안 데이터다. 알림은 서버에 쌓일
/// 때까지 기다려야 볼 수 있어 목록·안 읽음 점·모두 읽음을 확인할 길을 남긴다.
const _notificationApiKind = String.fromEnvironment('NOTIFICATION_API');

/// 실행 인자에 맞는 구현. 모르는 값이면 실제 서버로 간다.
NotificationApi _notificationApiFor(String kind) => switch (kind) {
  'mock' => MockNotificationApi(),
  'mock-empty' => MockNotificationApi(scenario: MockNotificationScenario.empty),
  'mock-error' => MockNotificationApi(scenario: MockNotificationScenario.error),
  _ => HttpNotificationApi(),
};

/// 양도마켓 화면이 어느 [ResaleApi] 를 쓸지 고르는 실행 인자. 기본은 실제 서버,
/// `--dart-define=RESALE_API=mock` 이면 시안 데이터, `mock-closed` 면 마켓이 닫힌
/// 화면이다. 서버로 만들기 어려운 상태(팔린 내 매물 등)를 볼 길을 남긴다.
const _resaleApiKind = String.fromEnvironment('RESALE_API');

/// 실행 인자에 맞는 구현. 모르는 값이면 실제 서버로 간다.
ResaleApi _resaleApiFor(String kind) => switch (kind) {
  'mock' => MockResaleApi(),
  'mock-empty' => MockResaleApi(scenario: ResaleMockScenario.empty),
  'mock-error' => MockResaleApi(scenario: ResaleMockScenario.error),
  // 닫힘 화면은 창 밖에만 나와 낮에는 볼 수가 없다. 이걸로 언제든 본다.
  'mock-closed' => MockResaleApi(scenario: ResaleMockScenario.closed),
  _ => HttpResaleApi(),
};

/// 컬렉션(소장품 카탈로그·제작·목록)이 어느 구현을 쓸지 고르는 실행 인자.
///
/// ```bash
/// flutter run --dart-define=MEMORY_API=mock    # 데모 공연 3개로. 백엔드 불필요
/// flutter run                                   # 기본값. 실제 서버(v1)
/// ```
///
/// 내 티켓([_ticketApiKind])과 같은 장치다. 누끼·깊이 모델은 기기 안에서만
/// 돌기 때문에, 서버가 멈춰도 제작 화면을 끝까지 확인할 길을 남긴다. 목으로
/// 만든 소장품은 앱을 끄면 사라진다.
const _memoryApiKind = String.fromEnvironment('MEMORY_API');

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

  /// 리프레시 토큰으로 새 액세스 토큰을 받아 세션에 넣는다. 성공하면 참. 세션은
  /// 네트워크를, 인터셉터는 인증 폴더를 모르므로 둘을 아는 여기서 조립한다.
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

  /// 고른 좌석이 좌석 선택 → 결제 → 완료 라우트 경계를 넘어 유지돼야 해서
  /// 라우트보다 위에서 만들어 [BookingScope] 로 내려준다. InheritedNotifier 는
  /// 알림 때 child 를 그대로 돌려주므로 MaterialApp 이 매번 리빌드되지는 않는다.
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

  /// 찜 목록 저장소. 검색·상세·찜리스트가 같은 목록을 봐야 해서 앱에 하나만
  /// 두고 [FavoriteScope] 로 내려준다. 공연은 서버([FavoriteApi]), 아티스트는
  /// 기기([FavoriteArtistStore])에 남는다.
  late final FavoriteStore _favoriteStore =
      widget.favoriteStore ??
      FavoriteStore(
        api: widget.favoriteApi ?? HttpFavoriteApi(),
        artistStore:
            widget.favoriteArtistStore ?? InMemoryFavoriteArtistStore(),
      );

  /// 직전에 본 로그인 여부. 세션은 토큰을 새로 받을 때도 알리므로, 로그인
  /// 여부가 실제로 바뀐 순간만 골라내야 찜 목록 요청이 한 번만 나간다.
  /// 처음엔 로그아웃으로 두어, 이미 로그인된 채 시작해도 한 번은 받아 온다.
  bool _wasLoggedIn = false;

  /// 소장품 저장소. API 들과 같은 이유로 앱에 하나만 두고 [TicketStoreScope] 로
  /// 내려준다.
  late final TicketStore _ticketStore =
      widget.ticketStore ?? InMemoryTicketStore();

  /// 기울임 효과 설정. 소장품 화면 여러 곳이 같은 값을 봐야 해서 앱에 하나만
  /// 두고 [TiltSettingScope] 로 내려준다.
  late final TiltSetting _tiltSetting = TiltSetting(
    widget.tiltSettingStore ?? InMemoryTiltSettingStore(),
  );

  /// 소장품 조작법 안내를 봤는가. 같은 이유로 앱에 하나만 두고
  /// [ViewerGuideScope] 로 내려준다.
  late final ViewerGuideSetting _viewerGuide = ViewerGuideSetting(
    widget.viewerGuideStore ?? InMemoryViewerGuideStore(),
  );

  late final MemoryConcertApi _memoryConcertApi =
      widget.memoryConcertApi ??
      (_memoryApiKind == 'mock'
          ? MockMemoryConcertApi()
          : HttpMemoryConcertApi());

  late final GoodsApi _goodsApi =
      widget.goodsApi ??
      (_memoryApiKind == 'mock' ? MockGoodsApi() : HttpGoodsApi());

  /// 양도마켓 화면이 쓰는 API. 다른 API 들과 같은 이유로 앱에 하나만 두고
  /// [ResaleApiScope] 로 내려준다.
  late final ResaleApi _resaleApi =
      widget.resaleApi ?? _resaleApiFor(_resaleApiKind);

  /// 화면이 쓰는 푸시 쪽. main 이 넘긴 푸시 서비스이거나, 안 넘겼으면 아무것도
  /// 하지 않는 구현이다. [PushNotificationScope] 로 내려준다.
  late final PushNotifications _push =
      widget.push ?? const NoopPushNotifications();

  /// 알림함 화면이 쓰는 API. 다른 API 들과 같은 이유로 앱에 하나만 두고
  /// [NotificationApiScope] 로 내려준다.
  late final NotificationApi _notificationApi =
      widget.notificationApi ?? _notificationApiFor(_notificationApiKind);

  /// 공연 상세의 알림 신청 버튼이 쓰는 API. 다른 API 들과 같은 이유로 앱에 하나만
  /// 두고 [AlarmApiScope] 로 내려준다.
  late final AlarmApi _alarmApi = widget.alarmApi ?? HttpAlarmApi();

  /// '제작중' job. 제작 화면이 시작하고, 완료 배너가 결과를 받는다. 둘이 서로
  /// 다른 라우트라 라우트보다 위에서 만들어 [CreationJobScope] 로 내려준다.
  /// 예매 컨트롤러를 여기서 만드는 것과 같은 이유다.
  late final CreationJob _creationJob = CreationJob(store: _ticketStore);

  /// 완료 배너가 소장품을 여는 데 쓴다. 배너는 [MaterialApp.builder] 자리에
  /// 있어서 그 아래의 Navigator 를 context 로는 못 찾는다.
  late final GlobalKey<NavigatorState> _navigatorKey =
      widget.navigatorKey ?? GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // 맨 앞에 꽂아야 그 뒤의 로그 인터셉터가 Authorization 헤더까지 찍는다.
    ApiClient.dio.interceptors.insert(0, _authInterceptor);

    // 인터셉터를 꽂은 바로 뒤에 부른다. 푸시 서비스는 main 에서 앱보다 먼저
    // 시작해 그때는 인증 요청을 못 보낸다. 순서가 바뀌면 등록이 401 로 튕긴다.
    _push.registerDevice().ignore();

    // 아티스트 찜은 기기에 있다. 검색 결과의 하트가 빨리 맞아야 해서 바로
    // 읽되, 기다리지는 않는다 — 수 ms 뒤 저장소가 알리면 하트가 채워진다.
    _favoriteStore.restoreArtists().ignore();

    // 기울임 설정도 같은 이유로 기다리지 않는다. 읽히기 전에 소장품을 열면
    // 기본값(켜짐)으로 잠깐 움직이다가 저장된 값으로 맞춰진다.
    _tiltSetting.restore().ignore();
    _viewerGuide.restore().ignore();

    _session.addListener(_syncFavoriteShows);
    _syncFavoriteShows();
  }

  /// 로그인하면 서버에서 찜 공연을 받아 두고, 로그아웃하면 버린다. 찜리스트를
  /// 열기 전에도 검색 결과·공연 상세의 하트가 맞아야 해서 미리 받는다. 실패는
  /// 삼킨다 — 찜리스트를 열면 그 화면이 다시 물어 실패를 알린다.
  void _syncFavoriteShows() {
    final isLoggedIn = _session.isLoggedIn;
    if (isLoggedIn == _wasLoggedIn) return;
    _wasLoggedIn = isLoggedIn;
    if (isLoggedIn) {
      _favoriteStore.loadShows().ignore();
    } else {
      _favoriteStore.clearShows();
    }
  }

  /// 첫 화면을 하나만 쌓는다. 첫 화면 이름이 '/' 아래에 있으면 기본으로 '/'(홈)를
  /// 먼저 쌓는데, 그러면 홈이 로딩 화면 밑에서 서버까지 부르고 로딩이 끝나면 홈이
  /// 둘이 된다. 그래서 이름에 상관없이 요청한 화면 하나만 만든다.
  List<Route<dynamic>> _generateInitialRoutes(String name) {
    final builder = AppRoutes.routes[name];
    assert(builder != null, '등록되지 않은 첫 화면: $name');
    return [
      MaterialPageRoute<void>(
        settings: RouteSettings(name: name),
        builder: builder!,
      ),
    ];
  }

  @override
  void dispose() {
    ApiClient.dio.interceptors.remove(_authInterceptor);
    _session.removeListener(_syncFavoriteShows);
    _bookingController.dispose();
    _creationJob.dispose();
    _tiltSetting.dispose();
    _viewerGuide.dispose();
    // 저장소는 우리가 만든 것(테스트·실패 대비 기본값)만 정리한다. main 이
    // 넘긴 것은 앱과 수명이 같다. 세션을 다루는 방식과 같다.
    if (widget.ticketStore == null) _ticketStore.dispose();
    if (widget.favoriteStore == null) _favoriteStore.dispose();
    // 세션은 우리가 만든 것(테스트용 기본값)만 정리한다. main 이 넘긴 것은
    // 앱과 수명이 같아 따로 정리할 일이 없다.
    if (widget.session == null) _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      title: 'TIMO',
      theme: AppTheme.light,
      navigatorKey: _navigatorKey,
      // 기본은 로딩 화면. 끝나면 홈으로 교체된다.
      initialRoute: widget.initialRoute,
      onGenerateInitialRoutes: _generateInitialRoutes,
      routes: AppRoutes.routes,
      // 소장품 제작은 화면 밖에서 도는 job 이라, 어느 화면에 있든 끝나면
      // 배너로 알려야 한다. 그래서 라우트가 아니라 앱 전체를 감싼다.
      //
      // 기기의 '동작 줄이기' 설정을 켜면 앰비언트 애니메이션 채널도 같이 멈춘다.
      builder: (context, child) {
        AmbientMotion.instance.enabled = !Motion.reduced(context);
        return CreationNotificationHost(
          navigatorKey: _navigatorKey,
          child: child!,
        );
      },
    );

    // 화면들이 읽는 범위(Scope). 앞에 있을수록 바깥에 놓인다.
    final scopes = <Widget Function(Widget child)>[
      (child) => AuthSessionScope(session: _session, child: child),
      (child) => AuthApiScope(api: _authApi, child: child),
      (child) => HomeApiScope(api: _homeApi, child: child),
      (child) => MyPageApiScope(api: _myPageApi, child: child),
      (child) => TicketApiScope(api: _ticketApi, child: child),
      (child) => ShowApiScope(api: _showApi, child: child),
      (child) => BookingApiScope(api: _bookingApi, child: child),
      (child) => BookingScope(controller: _bookingController, child: child),
      (child) => RecentSearchScope(store: _recentSearchStore, child: child),
      (child) => TicketStoreScope(store: _ticketStore, child: child),
      (child) => MemoryConcertApiScope(api: _memoryConcertApi, child: child),
      (child) => GoodsApiScope(api: _goodsApi, child: child),
      (child) => TiltSettingScope(setting: _tiltSetting, child: child),
      (child) => ViewerGuideScope(setting: _viewerGuide, child: child),
      (child) => ResaleApiScope(api: _resaleApi, child: child),
      (child) => CreationJobScope(job: _creationJob, child: child),
      (child) => FavoriteScope(store: _favoriteStore, child: child),
      (child) => AlarmApiScope(api: _alarmApi, child: child),
      (child) => NotificationApiScope(api: _notificationApi, child: child),
      (child) => PushNotificationScope(push: _push, child: child),
    ];
    return scopes.reversed.fold<Widget>(app, (child, wrap) => wrap(child));
  }
}
