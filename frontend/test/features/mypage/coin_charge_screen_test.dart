import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timo/core/network/api_exception.dart';
import 'package:timo/core/theme/app_theme.dart';
import 'package:timo/core/utils/formatters.dart';
import 'package:timo/core/widgets/async_boundary.dart';
import 'package:timo/features/auth/constants.dart';
import 'package:timo/features/auth/data/mock_auth_api.dart';
import 'package:timo/features/auth/data/token_storage.dart';
import 'package:timo/features/auth/screens/login_screen.dart';
import 'package:timo/features/auth/state/auth_session.dart';
import 'package:timo/features/auth/state/auth_session_scope.dart';
import 'package:timo/features/mypage/constants.dart';
import 'package:timo/features/mypage/data/mock_wallet_ledger.dart';
import 'package:timo/features/mypage/data/my_page_api.dart';
import 'package:timo/features/mypage/models/charge_amount.dart';
import 'package:timo/features/mypage/models/member_profile.dart';
import 'package:timo/features/mypage/models/wallet_summary.dart';
import 'package:timo/features/mypage/screens/coin_charge_screen.dart';
import 'package:timo/features/mypage/state/my_page_api_scope.dart';
import 'package:timo/routes/app_routes.dart';

/// 무엇을 요청받았는지 기록하는 목. 잔액 조회·충전 실패도 흉내 낸다.
class _RecordingMyPageApi implements MyPageApi {
  _RecordingMyPageApi({
    this.walletFailures = 0,
    this.chargeFails = false,
    this.latency = Duration.zero,
  });

  final ledger = MockWalletLedger();

  /// 충전 요청에 실린 금액들. 온 순서대로.
  final charged = <int>[];

  int walletCalls = 0;

  /// 잔액 조회를 처음 몇 번 실패시킬지.
  final int walletFailures;

  final bool chargeFails;

  /// 응답이 오기까지의 지연. 요청 중 상태를 보는 테스트가 넘긴다.
  final Duration latency;

  static const message = '인터넷 연결을 확인해주세요.';

  /// 충전 화면은 회원 정보를 쓰지 않는다.
  @override
  Future<MemberProfile> fetchProfile() => throw UnimplementedError();

  @override
  Future<WalletSummary> fetchWallet() async {
    walletCalls++;
    if (walletCalls <= walletFailures) throw const ApiException(message);
    return ledger.wallet;
  }

  @override
  Future<WalletSummary> charge(int amount) async {
    charged.add(amount);
    if (latency != Duration.zero) await Future.delayed(latency);
    if (chargeFails) throw const ApiException(message);
    return ledger.charge(amount);
  }
}

void main() {
  final routes = Map.of(AppRoutes.routes)..remove(AppRoutes.home);

  /// 금액 칸 하나를 가리키는 finder. 같은 글자가 요약 줄에도 나오므로 버튼으로
  /// 좁힌다.
  Finder preset(int value) => find.widgetWithText(
    OutlinedButton,
    MyPageStrings.withUnit(formatThousands(value)),
  );

  final submit = find.widgetWithText(FilledButton, MyPageStrings.chargeSubmit);

  bool submitEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(submit).onPressed != null;

  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpCharge(
    WidgetTester tester, {
    required MyPageApi api,
    bool loggedIn = true,
    Widget? home,
  }) async {
    usePhoneSize(tester);
    final session = AuthSession(storage: InMemoryTokenStorage());
    if (loggedIn) await session.signIn(MockAuthApi.tokens);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      AuthSessionScope(
        session: session,
        child: MyPageApiScope(
          api: api,
          child: MaterialApp(
            theme: AppTheme.light,
            home: home ?? const CoinChargeScreen(),
            routes: routes,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('화면 구성', () {
    testWidgets('제목 · 잔액 · 금액 칸 · 요약이 시안대로 보인다', (tester) async {
      await pumpCharge(tester, api: _RecordingMyPageApi());

      expect(find.text(MyPageStrings.chargeTitle), findsOneWidget);
      expect(find.text(MyPageStrings.walletTitle), findsOneWidget);
      expect(find.text('123,000'), findsOneWidget);
      // 이미 충전하러 들어온 자리라 잔액 카드 안에는 충전 입구가 없다.
      expect(find.text(MyPageStrings.charge), findsNothing);

      expect(find.text(MyPageStrings.chargeAmountTitle), findsOneWidget);
      expect(
        find.byType(OutlinedButton),
        findsNWidgets(ChargeAmount.presets.length),
      );
      expect(find.text(MyPageStrings.chargeAmountLabel), findsOneWidget);
      expect(find.text(MyPageStrings.balanceAfterCharge), findsOneWidget);
    });

    testWidgets('아무것도 안 고르면 충전 버튼이 잠겨 있다', (tester) async {
      await pumpCharge(tester, api: _RecordingMyPageApi());

      expect(submitEnabled(tester), isFalse);
    });
  });

  group('금액 고르기', () {
    testWidgets('금액 칸을 누르면 입력칸과 요약 두 줄이 함께 바뀐다', (tester) async {
      await pumpCharge(tester, api: _RecordingMyPageApi());

      await tester.tap(preset(10000));
      await tester.pump();

      // 입력칸 · 추가할 금액 두 군데에 같은 금액이 찍힌다(칸 자체까지 셋).
      expect(find.text('10,000'), findsNWidgets(1));
      expect(find.text(MyPageStrings.withUnit('10,000')), findsNWidgets(2));
      // 추가 후 잔액 = 현재 잔액 + 고른 금액.
      expect(find.text(MyPageStrings.withUnit('133,000')), findsOneWidget);
      expect(submitEnabled(tester), isTrue);
    });

    testWidgets('고른 칸은 체크와 시맨틱으로도 구분된다', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCharge(tester, api: _RecordingMyPageApi());

      await tester.tap(preset(30000));
      // 고름 표시는 애니메이션으로 나타난다. 다 끝난 뒤에 본다.
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(tester.getSemantics(preset(30000)), isSemantics(isSelected: true));
      expect(
        tester.getSemantics(preset(10000)),
        isNot(isSemantics(isSelected: true)),
      );
      handle.dispose();
    });

    testWidgets('직접 입력한 금액이 칸과 같으면 그 칸이 고른 것으로 보인다', (tester) async {
      await pumpCharge(tester, api: _RecordingMyPageApi());

      await tester.enterText(find.byType(TextField), '50000');
      await tester.pumpAndSettle();

      expect(find.text('50,000'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(submitEnabled(tester), isTrue);
    });

    testWidgets('한도 밖이면 안내가 뜨고 버튼이 잠긴다', (tester) async {
      await pumpCharge(tester, api: _RecordingMyPageApi());

      await tester.enterText(find.byType(TextField), '500');
      await tester.pump();
      expect(
        find.text(
          MyPageStrings.chargeBelowMin(formatThousands(ChargeAmount.min)),
        ),
        findsOneWidget,
      );
      expect(submitEnabled(tester), isFalse);

      // 한도를 넘는 자릿수는 입력칸이 잘라내므로 최대 금액을 넘길 수 없다.
      await tester.enterText(find.byType(TextField), '99999999');
      await tester.pump();
      expect(find.text('9,999,999'), findsOneWidget);
      expect(
        find.text(
          MyPageStrings.chargeAboveMax(formatThousands(ChargeAmount.max)),
        ),
        findsOneWidget,
      );
      expect(submitEnabled(tester), isFalse);
    });
  });

  group('충전하기', () {
    testWidgets('고른 금액으로 요청이 나가고 성공하면 결과 true 로 닫힌다', (tester) async {
      final api = _RecordingMyPageApi();
      Object? result;
      await pumpCharge(
        tester,
        api: api,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await Navigator.pushNamed(
                context,
                AppRoutes.coinCharge,
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.tap(preset(5000));
      await tester.pump();
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(api.charged, [5000]);
      expect(result, isTrue);
      expect(find.byType(CoinChargeScreen), findsNothing);
      expect(find.text(MyPageStrings.chargeSucceeded('5,000')), findsOneWidget);
    });

    testWidgets('응답을 기다리는 동안 다시 눌러도 요청은 한 번만 나간다', (tester) async {
      final api = _RecordingMyPageApi(
        latency: const Duration(milliseconds: 300),
      );
      await pumpCharge(tester, api: api);

      await tester.tap(preset(5000));
      await tester.pump();
      await tester.tap(submit);
      await tester.pump();

      expect(submitEnabled(tester), isFalse);
      await tester.tap(submit, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(api.charged, [5000]);
    });

    testWidgets('실패하면 문구가 뜨고 금액이 남아 다시 보낼 수 있다', (tester) async {
      final api = _RecordingMyPageApi(chargeFails: true);
      await pumpCharge(tester, api: api);

      await tester.tap(preset(10000));
      await tester.pump();
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(find.text(_RecordingMyPageApi.message), findsOneWidget);
      expect(find.byType(CoinChargeScreen), findsOneWidget);
      expect(find.text('10,000'), findsOneWidget);
      expect(submitEnabled(tester), isTrue);

      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(api.charged, [10000, 10000]);
    });
  });

  group('잔액 조회', () {
    testWidgets('실패하면 문구와 다시 시도가 보이고, 금액은 그대로 고를 수 있다', (tester) async {
      final api = _RecordingMyPageApi(walletFailures: 1);
      await pumpCharge(tester, api: api);

      expect(find.text(_RecordingMyPageApi.message), findsOneWidget);
      expect(find.text(AsyncBoundary.retryLabel), findsOneWidget);

      // 잔액을 몰라도 금액은 고를 수 있다. 추가 후 잔액 줄만 비어 있다.
      await tester.tap(preset(10000));
      await tester.pump();
      expect(find.text(MyPageStrings.balanceAfterCharge), findsOneWidget);
      expect(find.text(MyPageStrings.withUnit('133,000')), findsNothing);
      expect(submitEnabled(tester), isTrue);

      await tester.tap(find.text(AsyncBoundary.retryLabel));
      await tester.pumpAndSettle();
      expect(api.walletCalls, 2);
      expect(find.text('123,000'), findsOneWidget);
      expect(find.text(MyPageStrings.withUnit('133,000')), findsOneWidget);
    });
  });

  group('로그인 안 한 상태', () {
    testWidgets('안내와 로그인 버튼만 보인다', (tester) async {
      final api = _RecordingMyPageApi();
      await pumpCharge(tester, api: api, loggedIn: false);

      expect(find.text(MyPageStrings.chargeLoginPrompt), findsOneWidget);
      expect(find.text(MyPageStrings.chargeAmountTitle), findsNothing);
      expect(api.walletCalls, 0);

      await tester.tap(find.text(AuthStrings.login));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  testWidgets('뒤로가기를 누르면 이전 화면으로 돌아간다', (tester) async {
    await pumpCharge(
      tester,
      api: _RecordingMyPageApi(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.coinCharge),
            child: const Text('열기'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.byType(CoinChargeScreen), findsOneWidget);

    await tester.tap(find.byTooltip(MyPageStrings.back));
    await tester.pumpAndSettle();
    expect(find.byType(CoinChargeScreen), findsNothing);
    expect(find.text('열기'), findsOneWidget);
  });

  testWidgets('알림을 누르면 준비 중 안내가 뜬다', (tester) async {
    await pumpCharge(tester, api: _RecordingMyPageApi());

    await tester.tap(find.byTooltip(MyPageStrings.notifications));
    await tester.pumpAndSettle();

    expect(
      find.text(MyPageStrings.notReady(MyPageStrings.notifications)),
      findsOneWidget,
    );
  });
}
