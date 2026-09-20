import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo_gate/core/network/api_exception.dart';
import 'package:timo_gate/core/theme/app_theme.dart';
import 'package:timo_gate/features/auth/constants.dart';
import 'package:timo_gate/features/auth/data/mock_auth_api.dart';
import 'package:timo_gate/core/storage/device_storage.dart';
import 'package:timo_gate/features/auth/data/token_storage.dart';
import 'package:timo_gate/features/auth/models/auth_tokens.dart';
import 'package:timo_gate/features/auth/screens/login_screen.dart';
import 'package:timo_gate/features/auth/state/auth_session.dart';

void main() {
  /// 지연 0 인 목 API. 응답을 바로 받아야 하는 화면 단위 테스트에 꽂는다.
  const api = MockAuthApi(latency: Duration.zero);

  late InMemoryDeviceStorage storage;
  late AuthSession session;

  setUp(() {
    storage = InMemoryDeviceStorage();
    session = AuthSession(storage: storage);
  });

  /// 375×812 폰 크기. 좁은 폰에서 넘침이 나면 테스트가 바로 실패하므로
  /// 레이아웃 검사도 겸한다.
  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpLogin(WidgetTester tester, {MockAuthApi? withApi}) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LoginScreen(api: withApi ?? api, session: session),
      ),
    );
  }

  /// 하단 로그인 버튼. 화면에 FilledButton 은 이것 하나다.
  Finder loginButton() => find.byType(FilledButton);

  bool loginEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(loginButton()).onPressed != null;

  /// 0번이 아이디, 1번이 비밀번호.
  Finder fields() => find.byType(TextField);

  bool passwordObscured(WidgetTester tester) =>
      tester.widget<TextField>(fields().at(1)).obscureText;

  Future<void> fill(
    WidgetTester tester, {
    String? username,
    String? password,
  }) async {
    if (username != null) await tester.enterText(fields().at(0), username);
    if (password != null) await tester.enterText(fields().at(1), password);
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pumpAndSettle();
  }

  group('로그인 화면', () {
    testWidgets('제목·설명, 라벨 두 개, 칸 두 개, 로그인 버튼이 있다. 회원가입 링크는 없다', (
      tester,
    ) async {
      await pumpLogin(tester);

      expect(find.text(AuthStrings.loginTitle), findsOneWidget);
      expect(find.text(AuthStrings.loginSubtitle), findsOneWidget);
      // 라벨과 힌트가 같은 글자('아이디')라 둘씩 잡힌다.
      expect(find.text(AuthStrings.usernameLabel), findsNWidgets(2));
      expect(find.text(AuthStrings.passwordLabel), findsNWidgets(2));
      expect(fields(), findsNWidgets(2));
      expect(passwordObscured(tester), isTrue);
      expect(
        find.widgetWithText(FilledButton, AuthStrings.login),
        findsOneWidget,
      );
      expect(find.text('회원가입'), findsNothing);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('두 칸이 다 채워질 때만 버튼이 켜진다', (tester) async {
      await pumpLogin(tester);
      expect(loginEnabled(tester), isFalse);

      await fill(tester, username: 'admin');
      expect(loginEnabled(tester), isFalse);

      await fill(tester, password: 'abcd1234!');
      expect(loginEnabled(tester), isTrue);

      // 공백만 친 아이디는 빈 것으로 본다.
      await fill(tester, username: '   ');
      expect(loginEnabled(tester), isFalse);
    });

    testWidgets('요청 중에는 스피너가 보이고 버튼이 눌리지 않는다', (tester) async {
      // 지연 0 목은 첫 프레임에 바로 응답해 요청 중 상태를 볼 수 없다.
      await pumpLogin(tester, withApi: const MockAuthApi());
      await fill(
        tester,
        username: 'admin',
        password: MockAuthApi.wrongPassword,
      );
      await tester.tap(loginButton());
      await tester.pump();

      expect(
        find.descendant(
          of: loginButton(),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(loginEnabled(tester), isFalse);

      await tester.pump(AuthMetrics.mockLatency);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(AuthStrings.loginFailed), findsOneWidget);
    });

    testWidgets('틀린 비밀번호면 실패 문구가 뜨고 버튼은 도로 켜진다', (tester) async {
      await pumpLogin(tester);
      await fill(
        tester,
        username: 'admin',
        password: MockAuthApi.wrongPassword,
      );
      await tester.tap(loginButton());
      await settle(tester);

      expect(find.text(AuthStrings.loginFailed), findsOneWidget);
      expect(loginEnabled(tester), isTrue);
      expect(session.isLoggedIn, isFalse);
    });

    testWidgets('실패 문구는 어느 칸이든 다시 치면 사라진다', (tester) async {
      await pumpLogin(tester);
      await fill(
        tester,
        username: 'admin',
        password: MockAuthApi.wrongPassword,
      );
      await tester.tap(loginButton());
      await settle(tester);
      expect(find.text(AuthStrings.loginFailed), findsOneWidget);

      await fill(tester, username: 'admin2');
      expect(find.text(AuthStrings.loginFailed), findsNothing);
    });

    testWidgets('관리자가 아닌 계정은 맞는 비밀번호라도 거절 문구를 보이고 세션에 담지 않는다', (tester) async {
      final recording = _RecordingAuthApi();
      await pumpLogin(tester, withApi: recording);
      await fill(tester, username: 'fan', password: 'abcd1234!');
      await tester.tap(loginButton());
      await settle(tester);

      expect(find.text(AuthStrings.notAdmin), findsOneWidget);
      expect(find.text(AuthStrings.loginFailed), findsNothing);
      expect(loginEnabled(tester), isTrue);
      expect(session.isLoggedIn, isFalse);
      expect(storage.values, isEmpty);
      // 서버에 방금 생긴 팬 계정 세션은 끊어 둔다.
      expect(recording.loggedOut, [MockAuthApi.userTokens.refreshToken]);
    });

    testWidgets('정지된 계정처럼 입력 탓이 아닌 실패는 스낵바로 알리고 버튼을 다시 켠다', (tester) async {
      const suspended = ApiException(
        '정지된 계정입니다. 고객센터로 문의해 주세요.',
        status: 403,
        exceptionName: 'MemberSuspendedException',
      );
      await pumpLogin(tester, withApi: const _FailingLoginApi(suspended));
      await fill(tester, username: 'admin', password: 'abcd1234!');
      await tester.tap(loginButton());
      await settle(tester);

      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(suspended.message),
        ),
        findsOneWidget,
      );
      expect(find.text(AuthStrings.loginFailed), findsNothing);
      expect(loginEnabled(tester), isTrue);
      expect(session.isLoggedIn, isFalse);
    });

    testWidgets('관리자 계정이면 세션에 로그인 상태를 담고 기기에 저장한다', (tester) async {
      await pumpLogin(tester);
      await fill(
        tester,
        username: MockAuthApi.adminUsername,
        password: 'abcd1234!',
      );
      await tester.tap(loginButton());
      await settle(tester);

      expect(session.isLoggedIn, isTrue);
      expect(session.memberId, MockAuthApi.adminTokens.memberId);
      expect(
        storage.values[TokenStorageKeys.accessToken],
        MockAuthApi.adminTokens.accessToken,
      );
      expect(find.text(AuthStrings.loginFailed), findsNothing);
      expect(find.text(AuthStrings.notAdmin), findsNothing);
    });

    testWidgets('아이디 칸에서 다음을 누르면 비밀번호 칸으로 포커스가 간다', (tester) async {
      await pumpLogin(tester);
      await fill(tester, username: 'admin');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();

      final passwordField = tester.widget<TextField>(fields().at(1));
      expect(passwordField.focusNode!.hasFocus, isTrue);
    });

    testWidgets('비밀번호 칸에서 완료를 누르면 로그인한다', (tester) async {
      await pumpLogin(tester);
      await fill(
        tester,
        username: 'admin',
        password: MockAuthApi.wrongPassword,
      );
      await tester.tap(fields().at(1));
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      expect(find.text(AuthStrings.loginFailed), findsOneWidget);
    });

    testWidgets('눈 아이콘을 누르면 가려진 글자가 보인다', (tester) async {
      await pumpLogin(tester);
      expect(passwordObscured(tester), isTrue);

      await tester.tap(find.byTooltip(AuthStrings.showPassword));
      await tester.pump();

      expect(passwordObscured(tester), isFalse);
      expect(find.byTooltip(AuthStrings.hidePassword), findsOneWidget);
    });
  });
}

/// 로그인만 정해 둔 예외로 실패하는 가짜 API.
class _FailingLoginApi extends MockAuthApi {
  const _FailingLoginApi(this.error) : super(latency: Duration.zero);

  final ApiException error;

  @override
  Future<AuthTokens?> login({
    required String username,
    required String password,
  }) async {
    throw error;
  }
}

/// 로그아웃 요청에 실린 리프레시 토큰을 기록하는 목. 팬 계정 로그인 거절 때
/// 서버 세션을 끊는지 본다.
class _RecordingAuthApi extends MockAuthApi {
  _RecordingAuthApi() : super(latency: Duration.zero);

  final loggedOut = <String>[];

  @override
  Future<void> logout(String refreshToken) async {
    loggedOut.add(refreshToken);
  }
}
