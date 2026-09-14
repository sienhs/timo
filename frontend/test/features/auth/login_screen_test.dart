import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timo/core/network/api_exception.dart';
import 'package:timo/core/theme/app_theme.dart';
import 'package:timo/features/auth/constants.dart';
import 'package:timo/features/auth/data/mock_auth_api.dart';
import 'package:timo/features/auth/data/token_storage.dart';
import 'package:timo/features/auth/models/auth_tokens.dart';
import 'package:timo/features/auth/screens/login_screen.dart';
import 'package:timo/features/auth/screens/signup_phone_screen.dart';
import 'package:timo/features/auth/state/auth_session.dart';
import 'package:timo/core/widgets/timo_logo.dart';
import 'package:timo/features/home/data/mock_home_api.dart';
import 'package:timo/features/home/state/home_api_scope.dart';
import 'package:timo/routes/app_routes.dart';

void main() {
  /// 지연 0 인 목 API. 응답을 바로 받아야 하는 화면 단위 테스트에 꽂는다.
  const api = MockAuthApi(latency: Duration.zero);

  /// 로그인 성공이 담길 세션. 메모리 저장소라 테스트마다 새로 만든다.
  late InMemoryTokenStorage storage;
  late AuthSession session;

  setUp(() {
    storage = InMemoryTokenStorage();
    session = AuthSession(storage: storage);
  });

  /// 375×812 폰 크기. 좁은 폰에서 넘침(overflow)이 나면 테스트가 바로
  /// 실패하므로 레이아웃 검사도 겸한다.
  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// 홈('/')만 뺀 실제 라우트 표. MaterialApp 은 home 과 '/' 를 같이 두지
  /// 못하므로, 로그인 화면을 home 으로 띄우되 회원가입으로 넘어가는 동작은
  /// 진짜 라우트로 검사한다.
  final routes = Map.of(AppRoutes.routes)..remove(AppRoutes.home);

  Future<void> pumpLogin(WidgetTester tester, {MockAuthApi? withApi}) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LoginScreen(api: withApi ?? api, session: session),
        routes: routes,
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

  /// 두 칸에 글자를 넣고 한 프레임 그린다. null 인 칸은 건드리지 않는다.
  Future<void> fill(
    WidgetTester tester, {
    String? username,
    String? password,
  }) async {
    if (username != null) await tester.enterText(fields().at(0), username);
    if (password != null) await tester.enterText(fields().at(1), password);
    await tester.pump();
  }

  /// 지연 0 목 응답과 화면 전환 애니메이션을 끝까지 돌린다.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pumpAndSettle();
  }

  group('로그인 화면', () {
    testWidgets('시안 요소가 다 있다: 로고, 라벨 두 개, 칸 두 개, 로그인 버튼', (tester) async {
      await pumpLogin(tester);

      expect(find.byType(TimoLogo), findsOneWidget);
      // 라벨과 힌트가 같은 글자('아이디')라 둘씩 잡힌다.
      expect(find.text(AuthStrings.usernameLabel), findsNWidgets(2));
      expect(find.text(AuthStrings.passwordLabel), findsNWidgets(2));
      expect(fields(), findsNWidgets(2));
      expect(passwordObscured(tester), isTrue);
      expect(
        find.widgetWithText(FilledButton, AuthStrings.login),
        findsOneWidget,
      );
      expect(find.text(AuthStrings.signup), findsOneWidget);
      // 회원가입과 같은 틀을 쓰지만 단계 표시(n/4)는 없어야 한다.
      expect(find.textContaining('/${AuthMetrics.totalSteps}'), findsNothing);
    });

    testWidgets('들어오면 아이디 칸에 포커스가 있다', (tester) async {
      await pumpLogin(tester);
      await tester.pump();

      final editable = tester.widget<EditableText>(
        find.descendant(
          of: fields().at(0),
          matching: find.byType(EditableText),
        ),
      );
      expect(editable.focusNode.hasFocus, isTrue);
    });

    testWidgets('라우트로 열면 뒤로가기 화살표가 있다', (tester) async {
      // initialRoute 가 '/login' 이면 홈('/')이 먼저 깔리고 그 위에 로그인이
      // 올라간다. 라우트 등록과 뒤로가기를 한 번에 확인한다.
      usePhoneSize(tester);
      // 홈 탭이 공연 API 를 위에서 찾으므로 앱처럼 스코프로 감싼다.
      await tester.pumpWidget(
        HomeApiScope(
          api: const MockHomeApi(latency: Duration.zero),
          child: MaterialApp(
            theme: AppTheme.light,
            initialRoute: AppRoutes.login,
            routes: AppRoutes.routes,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('두 칸이 다 채워질 때만 버튼이 켜진다', (tester) async {
      await pumpLogin(tester);
      expect(loginEnabled(tester), isFalse);

      await fill(tester, username: 'timo');
      expect(loginEnabled(tester), isFalse);

      await fill(tester, password: 'abcd1234!');
      expect(loginEnabled(tester), isTrue);

      await fill(tester, password: '');
      expect(loginEnabled(tester), isFalse);

      // 공백만 친 아이디는 빈 것으로 본다.
      await fill(tester, username: '   ', password: 'abcd1234!');
      expect(loginEnabled(tester), isFalse);
    });

    testWidgets('요청 중에는 스피너가 보이고 버튼이 눌리지 않는다', (tester) async {
      // 지연 0 목은 첫 프레임에 바로 응답해 요청 중 상태를 볼 수 없다.
      // 기본 지연(400ms) 목을 쓰고 시계를 그만큼 돌린다.
      await pumpLogin(tester, withApi: const MockAuthApi());
      await fill(tester, username: 'timo', password: MockAuthApi.wrongPassword);
      await tester.tap(loginButton());
      await tester.pump();

      expect(
        find.descendant(
          of: loginButton(),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(find.text(AuthStrings.login), findsNothing);
      expect(loginEnabled(tester), isFalse);

      await tester.pump(AuthMetrics.mockLatency);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(AuthStrings.loginFailed), findsOneWidget);
    });

    testWidgets('틀린 비밀번호면 실패 문구가 뜨고 화면에 남는다', (tester) async {
      await pumpLogin(tester);
      await fill(tester, username: 'timo', password: MockAuthApi.wrongPassword);
      await tester.tap(loginButton());
      await settle(tester);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(AuthStrings.loginFailed), findsOneWidget);
      // 다시 시도할 수 있어야 하니 버튼은 도로 켜진다.
      expect(loginEnabled(tester), isTrue);
      expect(session.isLoggedIn, isFalse);
    });

    testWidgets('실패 문구는 어느 칸이든 다시 치면 사라진다', (tester) async {
      await pumpLogin(tester);
      await fill(tester, username: 'timo', password: MockAuthApi.wrongPassword);
      await tester.tap(loginButton());
      await settle(tester);
      expect(find.text(AuthStrings.loginFailed), findsOneWidget);

      await fill(tester, username: 'timo2');
      expect(find.text(AuthStrings.loginFailed), findsNothing);

      await tester.tap(loginButton());
      await settle(tester);
      expect(find.text(AuthStrings.loginFailed), findsOneWidget);

      await fill(tester, password: 'abcd1234!');
      expect(find.text(AuthStrings.loginFailed), findsNothing);
    });

    testWidgets('정지된 계정처럼 입력 탓이 아닌 실패는 스낵바로 알리고 버튼을 다시 켠다', (tester) async {
      const suspended = ApiException(
        '정지된 계정입니다. 고객센터로 문의해 주세요.',
        status: 403,
        exceptionName: 'MemberSuspendedException',
      );
      await pumpLogin(tester, withApi: const _FailingLoginApi(suspended));
      await fill(tester, username: 'timo', password: 'abcd1234!');
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
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(loginEnabled(tester), isTrue);
      expect(session.isLoggedIn, isFalse);
    });

    testWidgets('맞는 정보면 세션에 로그인 상태를 담고, true 를 돌려주며 닫힌다', (tester) async {
      usePhoneSize(tester);
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LoginScreen(api: api, session: session),
                  ),
                );
              },
              child: const Text('열기'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);

      await fill(tester, username: 'timo', password: 'abcd1234!');
      await tester.tap(loginButton());
      await settle(tester);

      expect(find.byType(LoginScreen), findsNothing);
      expect(result, isTrue);
      // 앱 전체가 로그인 상태가 되고, 기기에도 저장돼 다시 켜도 유지된다.
      expect(session.isLoggedIn, isTrue);
      expect(session.memberId, MockAuthApi.tokens.memberId);
      expect(
        storage.values[TokenStorageKeys.accessToken],
        MockAuthApi.tokens.accessToken,
      );
    });

    testWidgets('아이디 칸에서 다음을 누르면 비밀번호 칸으로 포커스가 간다', (tester) async {
      await pumpLogin(tester);
      await fill(tester, username: 'timo');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();

      final passwordField = tester.widget<TextField>(fields().at(1));
      expect(passwordField.focusNode!.hasFocus, isTrue);
    });

    testWidgets('비밀번호 칸에서 완료를 누르면 로그인한다. 버튼이 꺼져 있으면 아무 일 없다', (tester) async {
      await pumpLogin(tester);

      // 아이디만 있을 때: 비밀번호 칸에서 완료를 눌러도 요청이 안 나간다.
      await fill(tester, username: 'timo');
      await tester.tap(fields().at(1));
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(find.text(AuthStrings.loginFailed), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);

      // 둘 다 있을 때: 완료가 곧 로그인이다. 틀린 비밀번호라 실패 문구로
      // 요청이 나갔는지 확인한다.
      await fill(tester, password: MockAuthApi.wrongPassword);
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

    testWidgets('회원가입 링크를 누르면 전화번호 화면으로 간다', (tester) async {
      await pumpLogin(tester);
      await tester.tap(find.text(AuthStrings.signup));
      await tester.pumpAndSettle();

      expect(find.byType(SignupPhoneScreen), findsOneWidget);
    });
  });
}

/// 로그인만 정해 둔 예외로 실패하는 가짜 API. 정지·탈퇴 계정, 네트워크 끊김
/// 같은 "입력 탓이 아닌 실패" 를 화면이 어떻게 보여주는지 검사할 때 쓴다.
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
