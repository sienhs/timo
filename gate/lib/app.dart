import 'package:flutter/material.dart';

import 'core/network/api_client.dart';
import 'core/network/api_exception.dart';
import 'core/network/auth_interceptor.dart';
import 'core/storage/device_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/http_auth_api.dart';
import 'features/auth/data/mock_auth_api.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/state/auth_api_scope.dart';
import 'features/auth/state/auth_session.dart';
import 'features/auth/state/auth_session_scope.dart';
import 'features/auth/widgets/logout_button.dart';
import 'features/concert/data/concert_api.dart';
import 'features/concert/data/http_concert_api.dart';
import 'features/concert/data/mock_concert_api.dart';
import 'features/concert/data/selected_concert_storage.dart';
import 'features/concert/models/concert_summary.dart';
import 'features/concert/screens/concert_picker_screen.dart';
import 'features/concert/state/concert_api_scope.dart';
import 'features/scan/constants.dart';
import 'features/scan/data/http_scan_api.dart';
import 'features/scan/data/mock_scan_api.dart';
import 'features/scan/data/scan_api.dart';
import 'features/scan/models/gate_target.dart';
import 'features/scan/screens/scan_screen.dart';
import 'features/scan/state/scan_api_scope.dart';

/// 스캔 화면이 어느 [ScanApi] 를 쓸지 고르는 실행 인자.
///
/// ```bash
/// flutter run                                    # 기본값. 실제 서버 검표 API
/// flutter run --dart-define=SCAN_API=mock        # 서버 없이. 예매 ID 로 결과가 갈린다
/// flutter run --dart-define=SCAN_API=mock-error  # 매번 확인 실패
/// ```
///
/// 목은 실기기에서 결과 화면 세 가지를 서버 없이 다 보려는 실행용이다.
const _scanApiKind = String.fromEnvironment('SCAN_API');

/// 실행 인자에 맞는 구현. 모르는 값이면 실제 서버로 간다.
ScanApi _scanApiFor(String kind) => switch (kind) {
  'mock' => MockScanApi(),
  'mock-error' => MockScanApi(failing: true),
  _ => HttpScanApi(),
};

/// 로그인이 어느 [AuthApi] 를 쓸지 고르는 실행 인자.
///
/// ```bash
/// flutter run                                # 기본값. 실제 서버(팬 앱과 같은 /api/v1/auth)
/// flutter run --dart-define=AUTH_API=mock    # 서버 없이. 아이디 admin 이면 관리자
/// ```
///
/// 스캔과 달리 기본값이 서버다 — 인증 API 는 이미 있다. 목은 서버 없이 스캔
/// 화면까지 가 보려는 실행용이다.
const _authApiKind = String.fromEnvironment('AUTH_API');

AuthApi _authApiFor(String kind) => switch (kind) {
  'mock' => const MockAuthApi(),
  _ => HttpAuthApi(),
};

/// 공연 선택이 어느 [ConcertApi] 를 쓸지 고르는 실행 인자.
///
/// ```bash
/// flutter run                                       # 기본값. 실제 서버 공연 목록
/// flutter run --dart-define=CONCERT_API=mock        # 서버 없이. 오늘·예정·지난 공연 네 개
/// flutter run --dart-define=CONCERT_API=mock-error  # 매번 불러오기 실패
/// ```
const _concertApiKind = String.fromEnvironment('CONCERT_API');

ConcertApi _concertApiFor(String kind) => switch (kind) {
  'mock' => MockConcertApi(),
  'mock-error' => MockConcertApi(failing: true),
  _ => HttpConcertApi(),
};

class App extends StatefulWidget {
  const App({
    super.key,
    this.session,
    this.authApi,
    this.scanApi,
    this.concertApi,
    this.concertStorage,
    this.initialConcert,
  });

  /// 로그인 상태. main 이 기기 저장소에서 되살려 넘긴다. 안 넘기면(위젯 테스트)
  /// 메모리 저장소로 된 로그아웃 상태에서 시작한다.
  final AuthSession? session;

  /// 인증 API. 안 넘기면 [_authApiKind] 가 고른다. 테스트는 목을 넣는다.
  final AuthApi? authApi;

  /// 안 넘기면 [_scanApiKind] 가 고른다. 테스트는 목을 넣는다.
  final ScanApi? scanApi;

  /// 안 넘기면 [_concertApiKind] 가 고른다. 테스트는 목을 넣는다.
  final ConcertApi? concertApi;

  /// 고른 공연을 기억해 두는 곳. main 이 기기 저장소로 만들어 넘긴다. 안 넘기면
  /// 메모리에만 둔다(위젯 테스트).
  final SelectedConcertStorage? concertStorage;

  /// 앱을 켤 때 되살린 "지난번에 고른 공연". 없으면 공연 선택 화면부터 시작한다.
  final ConcertSummary? initialConcert;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final AuthSession _session =
      widget.session ?? AuthSession(storage: InMemoryDeviceStorage());

  /// 로그인 화면·로그아웃 버튼이 쓰는 인증 API. 앱에 하나만 두고 [AuthApiScope]
  /// 로 내려준다.
  late final AuthApi _authApi = widget.authApi ?? _authApiFor(_authApiKind);

  /// 앱에 하나만 두고 [ScanApiScope] 로 내려준다. 화면이 각자 만들면 목의
  /// "이미 입장" 기록이 화면마다 따로 놀고, 테스트에서 갈아끼울 자리도 없다.
  late final ScanApi _scanApi = widget.scanApi ?? _scanApiFor(_scanApiKind);

  late final ConcertApi _concertApi =
      widget.concertApi ?? _concertApiFor(_concertApiKind);

  late final SelectedConcertStorage _concertStorage =
      widget.concertStorage ?? SelectedConcertStorage(InMemoryDeviceStorage());

  /// 지금 검표하는 공연. null 이면 아직 고르지 않았다.
  late ConcertSummary? _concert = widget.initialConcert;

  /// 로그인 상태면 서버 요청에 토큰을 붙이고, 만료되면 재발급받아 요청을
  /// 이어가는 인터셉터. 공유 dio 에 꽂으므로 이 위젯이 사라질 때 빼 준다
  /// (테스트가 App 을 여러 번 띄워도 인터셉터가 쌓이지 않게).
  late final _authInterceptor = AuthInterceptor(
    dio: ApiClient.dio,
    accessToken: () => _session.accessToken,
    onUnauthorized: _session.signOut,
    reissue: _reissueAccessToken,
  );

  /// 리프레시 토큰으로 새 액세스 토큰을 받아 세션에 넣는다. 성공하면 참.
  ///
  /// 인터셉터가 부른다. 세션은 네트워크를 모르고, 인터셉터(공통 모듈)는 인증
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
    return _session.isLoggedIn;
  }

  /// 공연 선택 화면이 고른 공연을 넘기면 화면을 바꾸고 기기에 적어 둔다.
  ///
  /// 저장을 기다리지 않는다 — 화면은 바로 바뀌어야 하고, 저장이 실패해도
  /// (키스토어 오류) 이번 실행에서 검표하는 데는 지장이 없다. 다음 실행에서
  /// 다시 고르게 될 뿐이다.
  void _selectConcert(ConcertSummary concert) {
    setState(() => _concert = concert);
    _concertStorage.write(concert).ignore();
  }

  @override
  void initState() {
    super.initState();
    // 맨 앞에 꽂아야 그 뒤의 로그 인터셉터가 Authorization 헤더까지 찍는다.
    ApiClient.dio.interceptors.insert(0, _authInterceptor);
  }

  @override
  void dispose() {
    ApiClient.dio.interceptors.remove(_authInterceptor);
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
        child: ScanApiScope(
          api: _scanApi,
          child: ConcertApiScope(
            api: _concertApi,
            child: MaterialApp(
              title: ScanStrings.appName,
              theme: AppTheme.light,
              home: _RootScreen(
                concert: _concert,
                onConcertSelected: _selectConcert,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 로그인 여부와 공연 선택 여부로 첫 화면을 고른다.
/// 로그아웃 → 로그인, 공연 없음 → 공연 선택, 둘 다 있음 → 스캔.
///
/// 라우트로 오가지 않고 세션·선택을 구독해 바꿔 그린다. 어느 화면에서
/// 시작하든 "뒤로 가기" 로 돌아갈 곳이 없기 때문이다. 로그인 화면은 성공 시
/// 세션에 담기만 하고, 공연 선택 화면은 고른 공연을 콜백으로 알리기만 하며,
/// 로그아웃 버튼과 401 을 받은 인터셉터는 세션을 비우기만 한다 — 화면 전환은
/// 전부 여기서 일어난다.
///
/// 예외는 스캔 화면의 '공연 변경' 이다. 그때는 선택 화면을 **위에 띄운다** —
/// 고르지 않고 돌아오면 원래 공연으로 계속 검표해야 하므로 뒤로 가기가 있어야
/// 한다.
class _RootScreen extends StatelessWidget {
  const _RootScreen({required this.concert, required this.onConcertSelected});

  final ConcertSummary? concert;
  final ValueChanged<ConcertSummary> onConcertSelected;

  @override
  Widget build(BuildContext context) {
    final session = AuthSessionScope.of(context);
    if (!session.isLoggedIn) return const LoginScreen();

    final selected = concert;
    if (selected == null) {
      return ConcertPickerScreen(
        onSelected: onConcertSelected,
        trailing: const LogoutButton(),
      );
    }

    return ScanScreen(
      target: _targetOf(selected),
      onChangeTarget: () => _pushPicker(context),
      trailing: const LogoutButton(),
    );
  }

  Future<void> _pushPicker(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (routeContext) => ConcertPickerScreen(
        onSelected: (concert) {
          onConcertSelected(concert);
          Navigator.of(routeContext).pop();
        },
      ),
    ),
  );

  /// 목록 모델을 스캔 화면이 아는 형태로. 두 기능은 서로를 모르고, 둘을 아는
  /// 곳은 여기뿐이다.
  static GateTarget _targetOf(ConcertSummary concert) => GateTarget(
    concertId: concert.id,
    concertTitle: concert.title,
    venueName: concert.venueName,
    whenLabel: concert.whenLabel,
  );
}
