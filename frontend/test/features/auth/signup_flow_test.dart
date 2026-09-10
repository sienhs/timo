import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timo/core/network/api_exception.dart';
import 'package:timo/core/theme/app_theme.dart';
import 'package:timo/features/auth/constants.dart';
import 'package:timo/features/auth/data/mock_auth_api.dart';
import 'package:timo/features/auth/data/token_storage.dart';
import 'package:timo/features/auth/models/auth_tokens.dart';
import 'package:timo/features/auth/models/signup_draft.dart';
import 'package:timo/features/auth/screens/login_screen.dart';
import 'package:timo/features/auth/screens/signup_code_screen.dart';
import 'package:timo/features/auth/screens/signup_complete_screen.dart';
import 'package:timo/features/auth/screens/signup_name_screen.dart';
import 'package:timo/features/auth/screens/signup_nickname_screen.dart';
import 'package:timo/features/auth/screens/signup_password_screen.dart';
import 'package:timo/features/auth/screens/signup_phone_screen.dart';
import 'package:timo/features/auth/screens/signup_username_screen.dart';
import 'package:timo/features/auth/state/auth_api_scope.dart';
import 'package:timo/features/auth/state/auth_session.dart';
import 'package:timo/features/auth/state/auth_session_scope.dart';
import 'package:timo/features/auth/widgets/duplicate_check_button.dart';
import 'package:timo/features/auth/widgets/timo_logo.dart';
import 'package:timo/features/shell/screens/main_shell_screen.dart';
import 'package:timo/features/shell/widgets/app_bottom_nav_bar.dart';
import 'package:timo/routes/app_routes.dart';

void main() {
  /// 지연 0 인 목 API. 화면 단위 테스트에서 응답을 바로 받기 위해 주입한다.
  const api = MockAuthApi(latency: Duration.zero);

  /// 375×812 폰 크기. 좁은 폰에서 넘침(overflow)이 나면 테스트가 바로
  /// 실패하므로 레이아웃 검사도 겸한다.
  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// 홈('/')만 뺀 실제 라우트 표. MaterialApp 은 home 과 '/' 를 같이 두지
  /// 못하므로, 화면 하나를 home 으로 띄우되 다음 화면으로 넘어가는 동작은
  /// 진짜 라우트로 검사한다.
  final signupRoutes = Map.of(AppRoutes.routes)..remove(AppRoutes.home);

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: screen, routes: signupRoutes),
    );
  }

  /// 단계 화면의 하단 버튼. 팝업이 떠 있지 않을 때만 하나다.
  Finder nextButton() => find.byType(FilledButton);

  bool nextEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(nextButton()).onPressed != null;

  bool checkEnabled(WidgetTester tester) =>
      tester
          .widget<OutlinedButton>(
            find.descendant(
              of: find.byType(DuplicateCheckButton),
              matching: find.byType(OutlinedButton),
            ),
          )
          .onPressed !=
      null;

  /// 지연 0 목 응답과 화면 전환 애니메이션을 끝까지 돌린다.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pumpAndSettle();
  }

  /// 인증번호 화면이 떠 있는 동안 쓴다. 그 화면은 남은 시간을 매초 다시 그리므로
  /// pumpAndSettle 을 쓰면 3분이 다 지나 만료될 때까지 돌아 버린다. 대신 목
  /// 응답과 화면 전환(300ms)이 끝날 만큼만 시간을 흘린다.
  Future<void> settleFrames(WidgetTester tester) async {
    // 지연 0 목도 타이머로 응답하므로 시간을 조금 흘려야 응답이 도착하고, 그
    // 응답으로 화면을 바꾸는 프레임이 한 번 더 필요하다. 그다음 전환 애니메이션.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 600));
  }

  group('전화번호 화면', () {
    testWidgets('11자리 전엔 버튼이 꺼져 있고, 채우면 하이픈이 붙고 켜진다', (tester) async {
      await pumpScreen(tester, const SignupPhoneScreen(api: api));
      expect(nextEnabled(tester), isFalse);

      await tester.enterText(find.byType(TextField), '0101234567');
      await tester.pump();
      expect(find.text('010-1234-567'), findsOneWidget);
      expect(nextEnabled(tester), isFalse);

      await tester.enterText(find.byType(TextField), '01012345678');
      await tester.pump();
      expect(find.text('010-1234-5678'), findsOneWidget);
      expect(nextEnabled(tester), isTrue);
    });

    testWidgets('인증 번호 받기를 누르면 숫자만 담아 인증번호 화면으로 간다', (tester) async {
      await pumpScreen(tester, const SignupPhoneScreen(api: api));
      await tester.enterText(find.byType(TextField), '01012345678');
      await tester.pump();

      await tester.tap(nextButton());
      await settleFrames(tester);

      final next = tester.widget<SignupCodeScreen>(
        find.byType(SignupCodeScreen),
      );
      expect(next.draft.phoneNumber, '01012345678');
      // 서버가 준 유효 시간이 함께 넘어가 남은 시간의 출발점이 된다.
      expect(next.validFor, MockAuthApi.codeValidity);
    });
  });

  group('인증번호 화면', () {
    const draft = SignupDraft(phoneNumber: '01012345678');

    testWidgets('틀린 번호는 오류 문구가 뜨고, 다시 치면 사라진다', (tester) async {
      await pumpScreen(tester, const SignupCodeScreen(draft: draft, api: api));

      await tester.enterText(find.byType(TextField), MockAuthApi.invalidCode);
      await tester.pump();
      expect(nextEnabled(tester), isTrue);

      await tester.tap(nextButton());
      await settleFrames(tester);
      expect(find.text(AuthStrings.codeMismatch), findsOneWidget);
      expect(find.byType(SignupCodeScreen), findsOneWidget);

      await tester.enterText(find.byType(TextField), '00000');
      await tester.pump();
      expect(find.text(AuthStrings.codeMismatch), findsNothing);
    });

    testWidgets('남은 시간이 칸 안에서 줄어들고, 0 이 되면 만료 문구와 다시 받기로 바뀐다', (tester) async {
      await pumpScreen(
        tester,
        const SignupCodeScreen(
          draft: draft,
          api: api,
          validFor: Duration(seconds: 3),
        ),
      );
      expect(find.text('00:03'), findsOneWidget);
      expect(find.text(AuthStrings.verify), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:02'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();
      expect(nextEnabled(tester), isTrue);

      await tester.pump(const Duration(seconds: 2));
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text(AuthStrings.codeExpired), findsOneWidget);
      // 만료된 번호는 보낼 수 없고, 버튼이 다시 받기로 바뀐다.
      expect(find.text(AuthStrings.verify), findsNothing);
      expect(
        find.widgetWithText(FilledButton, AuthStrings.resendCode),
        findsOneWidget,
      );
      expect(nextEnabled(tester), isTrue);

      // 만료 문구는 글자를 고쳐도 남는다. 다시 받아야 풀린다.
      await tester.enterText(find.byType(TextField), '1234');
      await tester.pump();
      expect(find.text(AuthStrings.codeExpired), findsOneWidget);
    });

    testWidgets('다시 받기를 누르면 입력이 비워지고 새 유효 시간으로 다시 센다', (tester) async {
      await pumpScreen(
        tester,
        const SignupCodeScreen(
          draft: draft,
          api: api,
          validFor: Duration(seconds: 1),
        ),
      );
      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(AuthStrings.codeExpired), findsOneWidget);

      await tester.tap(nextButton());
      await settleFrames(tester);

      // 목의 유효 시간(3분)에서 다시 시작하고 옛 입력은 사라진다.
      expect(find.text('03:00'), findsOneWidget);
      expect(find.text(AuthStrings.codeExpired), findsNothing);
      expect(find.text('123456'), findsNothing);
      expect(find.text(AuthStrings.verify), findsOneWidget);
      expect(nextEnabled(tester), isFalse);
    });

    testWidgets('맞는 번호면 티켓을 초안에 담아 이름 화면으로 간다', (tester) async {
      await pumpScreen(tester, const SignupCodeScreen(draft: draft, api: api));

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();
      await tester.tap(nextButton());
      await settle(tester);

      final next = tester.widget<SignupNameScreen>(
        find.byType(SignupNameScreen),
      );
      expect(next.draft.phoneNumber, '01012345678');
      // 가입 요청에 실어 보낼 인증 티켓이 여기서부터 초안에 실린다.
      expect(next.draft.verificationTicket, MockAuthApi.mockTicket);
    });
  });

  group('이름 화면', () {
    testWidgets('한글 이름을 넣으면 다음 버튼이 켜진다', (tester) async {
      await pumpScreen(
        tester,
        const SignupNameScreen(draft: SignupDraft(phoneNumber: '01012345678')),
      );
      expect(nextEnabled(tester), isFalse);

      await tester.enterText(find.byType(TextField), '홍길동');
      await tester.pump();

      expect(find.text('홍길동'), findsOneWidget);
      expect(nextEnabled(tester), isTrue);
    });

    testWidgets('한 글자나 숫자가 섞이면 다음 버튼이 꺼져 있다', (tester) async {
      await pumpScreen(tester, const SignupNameScreen(draft: SignupDraft()));

      await tester.enterText(find.byType(TextField), '홍');
      await tester.pump();
      expect(nextEnabled(tester), isFalse);

      await tester.enterText(find.byType(TextField), '홍길동1');
      await tester.pump();
      expect(nextEnabled(tester), isFalse);
    });

    testWidgets('2/5 단계 표시와 시안 문구가 보인다', (tester) async {
      await pumpScreen(tester, const SignupNameScreen(draft: SignupDraft()));

      expect(find.text(AuthStrings.stepCounter(2)), findsOneWidget);
      expect(find.text(AuthStrings.nameTitle), findsOneWidget);
      expect(find.text(AuthStrings.nameLabel), findsOneWidget);
      expect(find.text(AuthStrings.next), findsOneWidget);
    });

    testWidgets('다음으로를 누르면 앞뒤 공백을 뗀 이름이 초안에 담긴다', (tester) async {
      await pumpScreen(tester, const SignupNameScreen(draft: SignupDraft()));

      await tester.enterText(find.byType(TextField), ' 홍길동 ');
      await tester.pump();
      await tester.tap(nextButton());
      await settle(tester);

      final next = tester.widget<SignupUsernameScreen>(
        find.byType(SignupUsernameScreen),
      );
      expect(next.draft.name, '홍길동');
    });
  });

  group('아이디 화면', () {
    testWidgets('형식이 맞아야 중복 확인이 눌리고, 대문자는 소문자로 받는다', (tester) async {
      await pumpScreen(
        tester,
        const SignupUsernameScreen(draft: SignupDraft(), api: api),
      );
      expect(checkEnabled(tester), isFalse);

      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();
      expect(find.text(AuthStrings.usernameRule), findsOneWidget);
      expect(checkEnabled(tester), isFalse);

      await tester.enterText(find.byType(TextField), 'Timo');
      await tester.pump();
      expect(find.text('timo'), findsOneWidget);
      expect(find.text(AuthStrings.usernameRule), findsNothing);
      expect(checkEnabled(tester), isTrue);
      // 중복 확인 전에는 다음으로가 잠겨 있다.
      expect(nextEnabled(tester), isFalse);
    });

    testWidgets('이미 쓰는 아이디는 오류가 뜨고 다음으로가 잠긴다', (tester) async {
      await pumpScreen(
        tester,
        const SignupUsernameScreen(draft: SignupDraft(), api: api),
      );

      await tester.enterText(find.byType(TextField), 'timo');
      await tester.pump();
      await tester.tap(find.byType(DuplicateCheckButton));
      await settle(tester);

      expect(find.text(AuthStrings.usernameTaken), findsOneWidget);
      expect(nextEnabled(tester), isFalse);
    });

    testWidgets('사용 가능하면 다음으로가 켜지고, 글자를 고치면 다시 잠긴다', (tester) async {
      await pumpScreen(
        tester,
        const SignupUsernameScreen(draft: SignupDraft(), api: api),
      );

      await tester.enterText(find.byType(TextField), 'minsuk_01');
      await tester.pump();
      await tester.tap(find.byType(DuplicateCheckButton));
      await settle(tester);

      expect(find.text(AuthStrings.usernameAvailable), findsOneWidget);
      expect(nextEnabled(tester), isTrue);

      await tester.enterText(find.byType(TextField), 'minsuk_012');
      await tester.pump();
      expect(find.text(AuthStrings.usernameAvailable), findsNothing);
      expect(nextEnabled(tester), isFalse);
    });

    testWidgets('다음으로를 누르면 팝업이 뜨고, 바깥을 누르면 닫히고, 동의하면 비밀번호 화면으로', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const SignupUsernameScreen(draft: SignupDraft(), api: api),
      );
      await tester.enterText(find.byType(TextField), 'minsuk_01');
      await tester.pump();
      await tester.tap(find.byType(DuplicateCheckButton));
      await settle(tester);

      await tester.tap(nextButton());
      await tester.pumpAndSettle();
      expect(find.text(AuthStrings.confirmTitle), findsOneWidget);

      // 팝업 바깥(화면 왼쪽 위)을 누르면 닫히고 확인 결과는 그대로다.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text(AuthStrings.confirmTitle), findsNothing);
      expect(find.byType(SignupUsernameScreen), findsOneWidget);
      expect(nextEnabled(tester), isTrue);

      await tester.tap(nextButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text(AuthStrings.confirmAgree));
      await tester.pumpAndSettle();

      final next = tester.widget<SignupPasswordScreen>(
        find.byType(SignupPasswordScreen),
      );
      expect(next.draft.username, 'minsuk_01');
    });
  });

  group('비밀번호 화면', () {
    testWidgets('규칙 미달이면 안내, 두 칸이 다르면 오류, 같으면 켜진다', (tester) async {
      await pumpScreen(
        tester,
        const SignupPasswordScreen(draft: SignupDraft()),
      );
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2));

      await tester.enterText(fields.at(0), 'abcd1234'); // 특수문자 없음
      await tester.pump();
      expect(find.text(AuthStrings.passwordRule), findsOneWidget);
      expect(nextEnabled(tester), isFalse);

      await tester.enterText(fields.at(0), 'abcd1234!');
      await tester.pump();
      expect(find.text(AuthStrings.passwordRule), findsNothing);

      await tester.enterText(fields.at(1), 'abcd1234');
      await tester.pump();
      expect(find.text(AuthStrings.passwordMismatch), findsOneWidget);
      expect(nextEnabled(tester), isFalse);

      await tester.enterText(fields.at(1), 'abcd1234!');
      await tester.pump();
      expect(find.text(AuthStrings.passwordMismatch), findsNothing);
      expect(nextEnabled(tester), isTrue);

      await tester.tap(nextButton());
      await settle(tester);
      final next = tester.widget<SignupNicknameScreen>(
        find.byType(SignupNicknameScreen),
      );
      expect(next.draft.password, 'abcd1234!');
    });

    testWidgets('눈 아이콘을 누르면 가려진 글자가 보인다', (tester) async {
      await pumpScreen(
        tester,
        const SignupPasswordScreen(draft: SignupDraft()),
      );
      final first = find.byType(TextField).first;
      expect(tester.widget<TextField>(first).obscureText, isTrue);

      await tester.tap(find.byTooltip(AuthStrings.showPassword).first);
      await tester.pump();

      expect(tester.widget<TextField>(first).obscureText, isFalse);
      expect(find.byTooltip(AuthStrings.hidePassword), findsOneWidget);
    });
  });

  group('닉네임 화면', () {
    testWidgets('한글 닉네임으로 중복 확인이 되고, 사용 가능하면 시작 버튼이 켜진다', (tester) async {
      await pumpScreen(
        tester,
        const SignupNicknameScreen(draft: SignupDraft(), api: api),
      );
      expect(find.text(AuthStrings.startSignup), findsOneWidget);

      await tester.enterText(find.byType(TextField), '티모');
      await tester.pump();
      await tester.tap(find.byType(DuplicateCheckButton));
      await settle(tester);
      expect(find.text(AuthStrings.nicknameTaken), findsOneWidget);
      expect(nextEnabled(tester), isFalse);

      await tester.enterText(find.byType(TextField), '티모2');
      await tester.pump();
      await tester.tap(find.byType(DuplicateCheckButton));
      await settle(tester);
      expect(find.text(AuthStrings.nicknameAvailable), findsOneWidget);
      expect(nextEnabled(tester), isTrue);
    });

    testWidgets('공백이 섞인 닉네임은 중복 확인이 눌리지 않는다', (tester) async {
      await pumpScreen(
        tester,
        const SignupNicknameScreen(draft: SignupDraft(), api: api),
      );

      await tester.enterText(find.byType(TextField), '티 모');
      await tester.pump();
      expect(find.text(AuthStrings.nicknameRule), findsOneWidget);
      expect(checkEnabled(tester), isFalse);
    });
  });

  group('서버 오류 표시', () {
    /// 서버에 닿지 못한 실패. 상태 코드가 없다.
    const networkError = ApiException('인터넷 연결을 확인해주세요.');

    Finder snackBarText(String message) => find.descendant(
      of: find.byType(SnackBar),
      matching: find.text(message),
    );

    testWidgets('전화번호: 발송 횟수 초과(429)는 스낵바로 알리고 버튼을 다시 켠다', (tester) async {
      const error = ApiException(
        '인증 문자 발송 횟수를 초과했습니다. 잠시 후 다시 시도해 주세요.',
        status: 429,
        exceptionName: 'SmsSendLimitExceededException',
      );
      await pumpScreen(
        tester,
        const SignupPhoneScreen(api: _FailingAuthApi(onSend: error)),
      );
      await tester.enterText(find.byType(TextField), '01012345678');
      await tester.pump();

      await tester.tap(nextButton());
      await settle(tester);

      expect(snackBarText(error.message), findsOneWidget);
      expect(find.byType(SignupPhoneScreen), findsOneWidget);
      expect(find.byType(SignupCodeScreen), findsNothing);
      expect(nextEnabled(tester), isTrue);
    });

    testWidgets('인증번호: 서버가 만료라고 하면 시간이 남았어도 만료 상태로 바뀐다', (tester) async {
      const error = ApiException(
        '인증 코드가 만료되었습니다. 다시 요청해 주세요.',
        status: 400,
        exceptionName: AuthServerErrors.smsCodeNotFound,
      );
      await pumpScreen(
        tester,
        const SignupCodeScreen(
          draft: SignupDraft(phoneNumber: '01012345678'),
          api: _FailingAuthApi(onVerify: error),
        ),
      );
      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();

      await tester.tap(nextButton());
      await settleFrames(tester);

      // 서버 문구 대신 우리 만료 문구와 다시 받기 버튼. 남은 시간도 0 으로.
      expect(find.text(AuthStrings.codeExpired), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, AuthStrings.resendCode),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(SignupCodeScreen), findsOneWidget);
    });

    testWidgets('인증번호: 시도 횟수 초과(429)처럼 다른 4xx 는 칸 아래에 서버 문구를 띄운다', (
      tester,
    ) async {
      const error = ApiException(
        '인증 시도 횟수를 초과했습니다. 다시 요청해 주세요.',
        status: 429,
        exceptionName: 'SmsAttemptExceededException',
      );
      await pumpScreen(
        tester,
        const SignupCodeScreen(
          draft: SignupDraft(phoneNumber: '01012345678'),
          api: _FailingAuthApi(onVerify: error),
        ),
      );
      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();

      await tester.tap(nextButton());
      await settleFrames(tester);

      expect(find.text(error.message), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(nextEnabled(tester), isTrue);

      // 다시 치면 문구가 사라진다.
      await tester.enterText(find.byType(TextField), '12345');
      await tester.pump();
      expect(find.text(error.message), findsNothing);
    });

    testWidgets('인증번호: 서버에 닿지 못하면 칸이 아니라 스낵바로 알린다', (tester) async {
      await pumpScreen(
        tester,
        const SignupCodeScreen(
          draft: SignupDraft(phoneNumber: '01012345678'),
          api: _FailingAuthApi(onVerify: networkError),
        ),
      );
      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();

      await tester.tap(nextButton());
      await settleFrames(tester);

      // 문구가 스낵바에만 있고 칸 아래에는 없다.
      expect(snackBarText(networkError.message), findsOneWidget);
      expect(find.text(networkError.message), findsOneWidget);
      expect(nextEnabled(tester), isTrue);
    });

    testWidgets('아이디: 중복 확인이 실패하면 스낵바를 띄우고 다시 누를 수 있다', (tester) async {
      await pumpScreen(
        tester,
        const SignupUsernameScreen(
          draft: SignupDraft(),
          api: _FailingAuthApi(onCheck: networkError),
        ),
      );
      await tester.enterText(find.byType(TextField), 'minsuk_01');
      await tester.pump();

      await tester.tap(find.byType(DuplicateCheckButton));
      await settle(tester);

      expect(snackBarText(networkError.message), findsOneWidget);
      expect(find.text(AuthStrings.usernameAvailable), findsNothing);
      expect(find.text(AuthStrings.usernameTaken), findsNothing);
      expect(checkEnabled(tester), isTrue);
      expect(nextEnabled(tester), isFalse);
    });

    testWidgets('닉네임: 가입 중 닉네임 중복(409)이면 칸 아래 문구로 바뀌고 버튼이 잠긴다', (tester) async {
      const error = ApiException(
        '이미 사용 중인 닉네임입니다.',
        status: 409,
        exceptionName: AuthServerErrors.nicknameDuplicated,
      );
      await pumpScreen(
        tester,
        const SignupNicknameScreen(
          draft: SignupDraft(),
          api: _FailingAuthApi(onSignUp: error),
        ),
      );
      await tester.enterText(find.byType(TextField), '티모2');
      await tester.pump();
      await tester.tap(find.byType(DuplicateCheckButton));
      await settle(tester);
      expect(nextEnabled(tester), isTrue);

      await tester.tap(nextButton());
      await settle(tester);

      expect(find.text(AuthStrings.nicknameTaken), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(SignupNicknameScreen), findsOneWidget);
      expect(nextEnabled(tester), isFalse);
    });

    testWidgets('닉네임: 가입 중 인증이 만료됐으면 스낵바를 띄우고 전화번호 화면으로 돌아간다', (tester) async {
      const error = ApiException(
        '본인인증이 만료되었습니다. 다시 인증해 주세요.',
        status: 400,
        exceptionName: AuthServerErrors.verificationTicketInvalid,
      );
      usePhoneSize(tester);
      // 홈 위에 전화번호 화면이 깔린 스택을 만들고, 그 위에 닉네임 화면을
      // 올린다. 중간 화면들은 이 검사의 관심이 아니다.
      await tester.pumpWidget(
        AuthApiScope(
          api: const _FailingAuthApi(onSignUp: error),
          child: MaterialApp(
            theme: AppTheme.light,
            initialRoute: AppRoutes.signupPhone,
            routes: AppRoutes.routes,
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .pushNamed(
            AppRoutes.signupNickname,
            arguments: const SignupDraft(
              phoneNumber: '01012345678',
              verificationTicket: 'expired-ticket',
            ),
          );
      await tester.pumpAndSettle();
      expect(find.byType(SignupNicknameScreen), findsOneWidget);

      await tester.enterText(find.byType(TextField), '티모2');
      await tester.pump();
      await tester.tap(find.byType(DuplicateCheckButton));
      await settle(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, AuthStrings.startSignup),
      );
      await settle(tester);

      expect(snackBarText(error.message), findsOneWidget);
      expect(find.byType(SignupPhoneScreen), findsOneWidget);
      expect(
        find.byType(SignupNicknameScreen, skipOffstage: false),
        findsNothing,
      );
    });

    testWidgets('닉네임: 가입이 네트워크로 실패하면 스낵바를 띄우고 버튼을 다시 켠다', (tester) async {
      await pumpScreen(
        tester,
        const SignupNicknameScreen(
          draft: SignupDraft(),
          api: _FailingAuthApi(onSignUp: networkError),
        ),
      );
      await tester.enterText(find.byType(TextField), '티모2');
      await tester.pump();
      await tester.tap(find.byType(DuplicateCheckButton));
      await settle(tester);

      await tester.tap(nextButton());
      await settle(tester);

      expect(snackBarText(networkError.message), findsOneWidget);
      expect(find.byType(SignupNicknameScreen), findsOneWidget);
      expect(nextEnabled(tester), isTrue);
    });
  });

  group('로고', () {
    testWidgets('이미지 파일이 없으면 TIMO 글자로 대신 그린다', (tester) async {
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: _EmptyAssetBundle(),
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: Center(child: TimoLogo())),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TIMO'), findsOneWidget);
    });
  });

  group('전체 흐름', () {
    Future<void> tapNext(WidgetTester tester, String label) async {
      await tester.tap(find.widgetWithText(FilledButton, label));
    }

    testWidgets('홈에서 시작해 가입을 마치면 완료 화면만 남고, 티켓 보러 가기는 홈으로 간다', (tester) async {
      usePhoneSize(tester);
      // 실제 라우트 표로 띄우면 화면들이 api·세션을 직접 받지 않으므로, 앱(App)이
      // 하는 것처럼 스코프로 감싸 목과 빈 세션을 내려준다.
      final session = AuthSession(storage: InMemoryTokenStorage());
      await tester.pumpWidget(
        AuthSessionScope(
          session: session,
          child: AuthApiScope(
            api: api,
            child: MaterialApp(
              theme: AppTheme.light,
              initialRoute: AppRoutes.home,
              routes: AppRoutes.routes,
            ),
          ),
        ),
      );

      // 마이페이지 탭의 임시 '로그인' 버튼 → 로그인 화면의 '회원가입' 링크로 진입
      await tester.tap(
        find.descendant(
          of: find.byType(AppBottomNavBar),
          matching: find.text('마이페이지'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(AuthStrings.login));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      await tester.tap(find.text(AuthStrings.signup));
      await tester.pumpAndSettle();
      expect(find.byType(SignupPhoneScreen), findsOneWidget);

      // 1/5 전화번호 → 인증번호
      await tester.enterText(find.byType(TextField), '01012345678');
      await tester.pump();
      await tapNext(tester, AuthStrings.requestCode);
      // 인증번호 화면은 매초 다시 그려서 pumpAndSettle 이 끝나지 않는다.
      await settleFrames(tester);
      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();
      await tapNext(tester, AuthStrings.verify);
      await settle(tester);

      // 2/5 이름
      await tester.enterText(find.byType(TextField), '홍길동');
      await tester.pump();
      await tapNext(tester, AuthStrings.next);
      await tester.pumpAndSettle();

      // 3/5 아이디 + 확정 팝업
      await tester.enterText(find.byType(TextField), 'minsuk_01');
      await tester.pump();
      await tester.tap(find.byType(DuplicateCheckButton));
      await settle(tester);
      await tapNext(tester, AuthStrings.next);
      await tester.pumpAndSettle();
      await tester.tap(find.text(AuthStrings.confirmAgree));
      await tester.pumpAndSettle();

      // 4/5 비밀번호
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'abcd1234!');
      await tester.enterText(fields.at(1), 'abcd1234!');
      await tester.pump();
      await tapNext(tester, AuthStrings.next);
      await tester.pumpAndSettle();

      // 5/5 닉네임 → 가입
      await tester.enterText(find.byType(TextField), '티모2');
      await tester.pump();
      await tester.tap(find.byType(DuplicateCheckButton));
      await settle(tester);
      await tapNext(tester, AuthStrings.startSignup);
      await settle(tester);

      // 완료 화면만 남고 입력 화면들은 스택에서 사라졌다.
      expect(find.byType(SignupCompleteScreen), findsOneWidget);
      expect(find.text(AuthStrings.completeTitle), findsOneWidget);
      expect(
        find.byType(SignupNicknameScreen, skipOffstage: false),
        findsNothing,
      );
      expect(find.byType(SignupPhoneScreen, skipOffstage: false), findsNothing);
      // 가입을 거쳐 왔으니 로그인 화면으로 되돌아갈 이유도 없다.
      expect(find.byType(LoginScreen, skipOffstage: false), findsNothing);
      // 가입 응답의 토큰이 세션에 담겨 바로 로그인 상태다.
      expect(session.isLoggedIn, isTrue);
      expect(session.memberId, MockAuthApi.tokens.memberId);

      // 티켓 보러 가기 → 홈 셸
      await tapNext(tester, AuthStrings.goToTickets);
      await tester.pumpAndSettle();
      expect(find.byType(MainShellScreen), findsOneWidget);
      expect(find.byType(SignupCompleteScreen), findsNothing);

      // 마이페이지 탭의 임시 버튼도 로그인 상태를 따라 '로그아웃' 으로 바뀌어 있다.
      await tester.tap(
        find.descendant(
          of: find.byType(AppBottomNavBar),
          matching: find.text('마이페이지'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(AuthStrings.logout), findsOneWidget);
    });
  });
}

/// 정해 둔 요청만 실패하는 가짜 API. 나머지는 목과 같다.
///
/// 화면이 서버 실패를 어떻게 보여주는지(칸 아래 문구인지 스낵바인지, 버튼이
/// 다시 켜지는지) 검사할 때 쓴다. 실패시킬 요청의 예외만 넣어 준다.
class _FailingAuthApi extends MockAuthApi {
  const _FailingAuthApi({
    this.onSend,
    this.onVerify,
    this.onCheck,
    this.onSignUp,
  }) : super(latency: Duration.zero);

  final ApiException? onSend;
  final ApiException? onVerify;

  /// 아이디·닉네임 중복 확인 둘 다.
  final ApiException? onCheck;
  final ApiException? onSignUp;

  @override
  Future<Duration> requestVerificationCode(String phoneNumber) async {
    if (onSend != null) throw onSend!;
    return super.requestVerificationCode(phoneNumber);
  }

  @override
  Future<String?> verifyCode({
    required String phoneNumber,
    required String code,
  }) async {
    if (onVerify != null) throw onVerify!;
    return super.verifyCode(phoneNumber: phoneNumber, code: code);
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    if (onCheck != null) throw onCheck!;
    return super.isUsernameAvailable(username);
  }

  @override
  Future<bool> isNicknameAvailable(String nickname) async {
    if (onCheck != null) throw onCheck!;
    return super.isNicknameAvailable(nickname);
  }

  @override
  Future<AuthTokens> signUp(SignupDraft draft) async {
    if (onSignUp != null) throw onSignUp!;
    return super.signUp(draft);
  }
}

/// 이미지 파일이 하나도 없는 에셋 번들. 로고 파일이 없을 때의 폴백을 검사한다.
///
/// 에셋 목록(매니페스트)은 비어 있는 채로 정상 응답해야 한다. 목록 자체를
/// 못 읽으면 이미지 키를 정하는 단계에서 실패하는데, 그 오류는 errorBuilder
/// 까지 오지 않는다. 실제 기기에서는 목록이 항상 있으므로 이 조건이 맞다.
class _EmptyAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(<String, Object>{})!;
    }
    if (key == 'AssetManifest.json') {
      return ByteData.sublistView(utf8.encode('{}'));
    }
    throw FlutterError('테스트용 빈 번들에는 $key 가 없다');
  }
}
