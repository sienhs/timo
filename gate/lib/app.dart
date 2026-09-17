import 'package:flutter/material.dart';

import 'core/network/api_client.dart';
import 'core/network/api_exception.dart';
import 'core/network/auth_interceptor.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/http_auth_api.dart';
import 'features/auth/data/mock_auth_api.dart';
import 'features/auth/data/token_storage.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/state/auth_api_scope.dart';
import 'features/auth/state/auth_session.dart';
import 'features/auth/state/auth_session_scope.dart';
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

class App extends StatefulWidget {
  const App({super.key, this.session, this.authApi, this.scanApi, this.target});

  /// 로그인 상태. main 이 기기 저장소에서 되살려 넘긴다. 안 넘기면(위젯 테스트)
  /// 메모리 저장소로 된 로그아웃 상태에서 시작한다.
  final AuthSession? session;

  /// 인증 API. 안 넘기면 [_authApiKind] 가 고른다. 테스트는 목을 넣는다.
  final AuthApi? authApi;

  /// 안 넘기면 [_scanApiKind] 가 고른다. 테스트는 목을 넣는다.
  final ScanApi? scanApi;

  /// 검표할 공연. 안 넘기면 목 값. 공연 선택 화면이 붙으면 그 화면이 이 값을
  /// 만들어 넘긴다.
  final GateTarget? target;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final AuthSession _session =
      widget.session ?? AuthSession(storage: InMemoryTokenStorage());

  /// 로그인 화면·로그아웃 버튼이 쓰는 인증 API. 앱에 하나만 두고 [AuthApiScope]
  /// 로 내려준다.
  late final AuthApi _authApi = widget.authApi ?? _authApiFor(_authApiKind);

  /// 앱에 하나만 두고 [ScanApiScope] 로 내려준다. 화면이 각자 만들면 목의
  /// "이미 입장" 기록이 화면마다 따로 놀고, 테스트에서 갈아끼울 자리도 없다.
  late final ScanApi _scanApi = widget.scanApi ?? _scanApiFor(_scanApiKind);

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
          child: MaterialApp(
            title: ScanStrings.appName,
            theme: AppTheme.light,
            home: _RootScreen(target: widget.target ?? MockScanApi.target),
          ),
        ),
      ),
    );
  }
}

/// 로그인 여부로 첫 화면을 고른다. 로그아웃 상태면 로그인, 아니면 스캔.
///
/// 라우트로 오가지 않고 세션을 구독해 바꿔 그린다. 화면이 둘뿐이고, 어느 쪽에서
/// 시작하든 "뒤로 가기" 로 돌아갈 곳이 없기 때문이다. 로그인 화면은 성공 시
/// 세션에 담기만 하고, 스캔 화면의 로그아웃 버튼과 401 을 받은 인터셉터는 세션을
/// 비우기만 한다 — 화면 전환은 전부 여기서 일어난다.
class _RootScreen extends StatelessWidget {
  const _RootScreen({required this.target});

  final GateTarget target;

  @override
  Widget build(BuildContext context) {
    final session = AuthSessionScope.of(context);
    return session.isLoggedIn
        ? ScanScreen(target: target)
        : const LoginScreen();
  }
}
