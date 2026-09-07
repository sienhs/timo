import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timo/core/theme/app_theme.dart';
import 'package:timo/features/auth/constants.dart';
import 'package:timo/features/auth/data/mock_auth_api.dart';
import 'package:timo/features/auth/models/signup_draft.dart';
import 'package:timo/features/auth/screens/signup_code_screen.dart';
import 'package:timo/features/auth/screens/signup_complete_screen.dart';
import 'package:timo/features/auth/screens/signup_name_screen.dart';
import 'package:timo/features/auth/screens/signup_nickname_screen.dart';
import 'package:timo/features/auth/screens/signup_password_screen.dart';
import 'package:timo/features/auth/screens/signup_phone_screen.dart';
import 'package:timo/features/auth/screens/signup_username_screen.dart';
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
      await settle(tester);

      final next = tester.widget<SignupCodeScreen>(
        find.byType(SignupCodeScreen),
      );
      expect(next.draft.phoneNumber, '01012345678');
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
      await settle(tester);
      expect(find.text(AuthStrings.codeMismatch), findsOneWidget);
      expect(find.byType(SignupCodeScreen), findsOneWidget);

      await tester.enterText(find.byType(TextField), '00000');
      await tester.pump();
      expect(find.text(AuthStrings.codeMismatch), findsNothing);
    });

    testWidgets('맞는 번호면 이름 화면으로 가고 초안이 이어진다', (tester) async {
      await pumpScreen(tester, const SignupCodeScreen(draft: draft, api: api));

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();
      await tester.tap(nextButton());
      await settle(tester);

      final next = tester.widget<SignupNameScreen>(
        find.byType(SignupNameScreen),
      );
      expect(next.draft.phoneNumber, '01012345678');
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
    /// 실제 라우트 표로 띄우면 화면들이 기본 목 API(지연 400ms)를 쓴다.
    /// pumpAndSettle 은 예약된 프레임이 없으면 바로 돌아오므로 지연만큼
    /// 시계를 먼저 돌린다.
    Future<void> settleMock(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(AuthMetrics.mockLatency);
      await tester.pumpAndSettle();
    }

    Future<void> tapNext(WidgetTester tester, String label) async {
      await tester.tap(find.widgetWithText(FilledButton, label));
    }

    testWidgets('홈에서 시작해 가입을 마치면 완료 화면만 남고, 티켓 보러 가기는 홈으로 간다', (tester) async {
      usePhoneSize(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          initialRoute: AppRoutes.home,
          routes: AppRoutes.routes,
        ),
      );

      // 마이페이지 탭의 임시 버튼으로 진입
      await tester.tap(
        find.descendant(
          of: find.byType(AppBottomNavBar),
          matching: find.text('마이페이지'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('회원가입'));
      await tester.pumpAndSettle();
      expect(find.byType(SignupPhoneScreen), findsOneWidget);

      // 1/5 전화번호 → 인증번호
      await tester.enterText(find.byType(TextField), '01012345678');
      await tester.pump();
      await tapNext(tester, AuthStrings.requestCode);
      await settleMock(tester);
      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();
      await tapNext(tester, AuthStrings.verify);
      await settleMock(tester);

      // 2/5 이름
      await tester.enterText(find.byType(TextField), '홍길동');
      await tester.pump();
      await tapNext(tester, AuthStrings.next);
      await tester.pumpAndSettle();

      // 3/5 아이디 + 확정 팝업
      await tester.enterText(find.byType(TextField), 'minsuk_01');
      await tester.pump();
      await tester.tap(find.byType(DuplicateCheckButton));
      await settleMock(tester);
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
      await settleMock(tester);
      await tapNext(tester, AuthStrings.startSignup);
      await settleMock(tester);

      // 완료 화면만 남고 입력 화면들은 스택에서 사라졌다.
      expect(find.byType(SignupCompleteScreen), findsOneWidget);
      expect(find.text(AuthStrings.completeTitle), findsOneWidget);
      expect(
        find.byType(SignupNicknameScreen, skipOffstage: false),
        findsNothing,
      );
      expect(find.byType(SignupPhoneScreen, skipOffstage: false), findsNothing);

      // 티켓 보러 가기 → 홈 셸
      await tapNext(tester, AuthStrings.goToTickets);
      await tester.pumpAndSettle();
      expect(find.byType(MainShellScreen), findsOneWidget);
      expect(find.byType(SignupCompleteScreen), findsNothing);
    });
  });
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
