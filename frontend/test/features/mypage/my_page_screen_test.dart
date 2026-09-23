import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timo/core/network/api_exception.dart';
import 'package:timo/core/theme/app_theme.dart';
import 'package:timo/core/widgets/async_boundary.dart';
import 'package:timo/core/widgets/error_snack_bar.dart';
import 'package:timo/features/auth/constants.dart';
import 'package:timo/features/auth/data/mock_auth_api.dart';
import 'package:timo/features/auth/data/token_storage.dart';
import 'package:timo/features/auth/models/auth_tokens.dart';
import 'package:timo/features/auth/screens/login_screen.dart';
import 'package:timo/features/auth/state/auth_api_scope.dart';
import 'package:timo/features/auth/state/auth_session.dart';
import 'package:timo/features/auth/state/auth_session_scope.dart';
import 'package:timo/features/mypage/constants.dart';
import 'package:timo/features/mypage/data/mock_my_page_api.dart';
import 'package:timo/features/mypage/data/mock_my_page_data.dart';
import 'package:timo/features/mypage/data/mock_wallet_ledger.dart';
import 'package:timo/features/mypage/data/my_page_api.dart';
import 'package:timo/features/mypage/models/member_profile.dart';
import 'package:timo/features/mypage/models/wallet_summary.dart';
import 'package:timo/features/mypage/models/wallet_transaction.dart';
import 'package:timo/features/mypage/screens/coin_charge_screen.dart';
import 'package:timo/features/mypage/screens/my_page_screen.dart';
import 'package:timo/features/mypage/state/my_page_api_scope.dart';
import 'package:timo/features/mypage/widgets/transaction_history_card.dart';
import 'package:timo/features/mypage/widgets/transaction_tile.dart';
import 'package:timo/features/notification/notification_destination.dart';
import 'package:timo/features/notification/push_notification_scope.dart';
import 'package:timo/features/notification/push_notification_service.dart';
import 'package:timo/routes/app_routes.dart';

/// 서버에 로그아웃을 알렸는지 기록하는 목. 나머지 동작은 [MockAuthApi] 그대로다.
class _RecordingAuthApi extends MockAuthApi {
  _RecordingAuthApi() : super(latency: Duration.zero);

  /// 로그아웃 요청에 실린 리프레시 토큰들. 온 순서대로.
  final loggedOutWith = <String>[];

  @override
  Future<void> logout(String refreshToken) {
    loggedOutWith.add(refreshToken);
    return super.logout(refreshToken);
  }
}

/// 푸시 토큰 해제를 기록하는 가짜. 진짜 구현은 만들 때 Firebase 를 건드려
/// 테스트에서 못 만든다.
///
/// 불린 횟수만이 아니라 **불린 시점에 아직 로그인 상태였는지**를 함께 남긴다.
/// 해제 API 는 인증 헤더로 요청자를 알아내므로 세션을 비운 뒤에 부르면 401 로
/// 튕긴다. 순서가 뒤집혀도 호출 횟수만 세면 통과해 버린다.
class _RecordingPushRegistrar implements PushNotifications {
  _RecordingPushRegistrar(this._session);

  final AuthSession _session;

  int calls = 0;
  bool? loggedInWhenCalled;

  @override
  Future<void> unregisterDevice() async {
    calls++;
    loggedInWhenCalled = _session.isLoggedIn;
  }

  /// 마이페이지는 이걸 쓰지 않는다. 알림으로 켜졌는지는 로딩 화면이 묻는다.
  @override
  NotificationDestination? takeLaunchDestination() => null;

  /// 마이페이지는 이걸 쓰지 않는다. 기기 등록은 App 이 뜨면서 부른다.
  @override
  Future<void> registerDevice() async {}

  @override
  Stream<int> get unreadCounts => const Stream.empty();
}

/// 처음 몇 번은 실패하고 그다음부터 성공하는 목. 다시 시도를 검사한다.
class _FlakyMyPageApi implements MyPageApi {
  _FlakyMyPageApi({required this.failuresBeforeSuccess});

  final int failuresBeforeSuccess;
  int profileCalls = 0;
  int walletCalls = 0;

  /// 예매자 실명은 결제 흐름만 쓴다. 이 목이 붙는 화면은 부르지 않는다.
  @override
  Future<String> fetchBookerName() => throw UnimplementedError();

  static const message = '인터넷 연결을 확인해주세요.';

  @override
  Future<MemberProfile> fetchProfile() {
    profileCalls++;
    if (profileCalls <= failuresBeforeSuccess) {
      return Future.error(const ApiException(message));
    }
    return Future.value(MockMyPageData.profile);
  }

  @override
  Future<WalletSummary> fetchWallet() {
    walletCalls++;
    if (walletCalls <= failuresBeforeSuccess) {
      return Future.error(const ApiException(message));
    }
    return Future.value(MockMyPageData.wallet);
  }

  /// 이 목은 조회 실패만 흉내 낸다. 충전은 쓰지 않는다.
  @override
  Future<WalletSummary> charge(int amount) => throw UnimplementedError();
}

void main() {
  // 알림함은 서버 API 를 쓰는 별도 화면이라 여기서는 빈 화면으로 바꿔 끼운다.
  // 여기서 볼 것은 알림 아이콘이 그 화면을 여느냐지 그 화면의 내용이 아니다.
  const notificationsLabel = '알림함';
  final routes = Map.of(AppRoutes.routes)
    ..remove(AppRoutes.home)
    ..[AppRoutes.notifications] = (_) =>
        const Scaffold(body: Text(notificationsLabel));

  /// 서버에 닿지 못하는 상황을 흉내 내는 토큰으로 로그인한 상태.
  const offlineTokens = AuthTokens(
    memberId: 1,
    accessToken: 'mock-access-token',
    refreshToken: MockAuthApi.offlineRefreshToken,
    accessTokenExpiresIn: Duration(minutes: 30),
  );

  late _RecordingAuthApi authApi;
  late _RecordingPushRegistrar pushRegistrar;

  /// 360 x 800 dp. 시안 폭에서 글자가 넘치지 않는지 함께 본다.
  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<AuthSession> pumpMyPage(
    WidgetTester tester, {
    required bool loggedIn,
    AuthTokens tokens = MockAuthApi.tokens,
    MyPageApi api = const MockMyPageApi(latency: Duration.zero),
    VoidCallback? onBackPressed,
  }) async {
    usePhoneSize(tester);
    authApi = _RecordingAuthApi();
    final session = AuthSession(storage: InMemoryTokenStorage());
    pushRegistrar = _RecordingPushRegistrar(session);
    if (loggedIn) await session.signIn(tokens);
    await tester.pumpWidget(
      AuthSessionScope(
        session: session,
        child: AuthApiScope(
          api: authApi,
          child: MyPageApiScope(
            api: api,
            child: PushNotificationScope(
              push: pushRegistrar,
              child: MaterialApp(
                theme: AppTheme.light,
                home: Scaffold(
                  body: MyPageScreen(onBackPressed: onBackPressed),
                ),
                routes: routes,
              ),
            ),
          ),
        ),
      ),
    );
    return session;
  }

  /// 목 응답이 도착해 화면이 채워질 때까지.
  Future<void> settle(WidgetTester tester) => tester.pumpAndSettle();

  group('로그인 안 한 상태', () {
    testWidgets('안내와 로그인 버튼이 보이고, 누르면 로그인 화면으로 간다', (tester) async {
      await pumpMyPage(tester, loggedIn: false);

      expect(find.text(MyPageStrings.loginPrompt), findsOneWidget);
      expect(find.text(AuthStrings.login), findsOneWidget);
      expect(find.text(AuthStrings.logout), findsNothing);

      await tester.tap(find.text(AuthStrings.login));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('스코프 없이 띄우면 로그아웃 상태로 그린다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: MyPageScreen()),
          routes: routes,
        ),
      );

      expect(find.text(AuthStrings.login), findsOneWidget);
    });
  });

  group('로그인 상태', () {
    testWidgets('응답을 기다리는 동안 스피너가 돌고 인사말은 아직 없다', (tester) async {
      await pumpMyPage(
        tester,
        loggedIn: true,
        api: const MockMyPageApi(latency: Duration(seconds: 1)),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining(MyPageStrings.greetingSuffix), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('닉네임 인사말 · 잔액 · 코인 내역이 시안대로 보인다', (tester) async {
      await pumpMyPage(tester, loggedIn: true);
      await settle(tester);

      // 인사말은 닉네임(굵게)과 나머지가 한 Text.rich 안에 있다.
      expect(
        find.textContaining(
          MockMyPageData.profile.nickname,
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(find.text(MyPageStrings.walletTitle), findsOneWidget);
      expect(find.text('123,000'), findsOneWidget);
      expect(find.text(MyPageStrings.charge), findsOneWidget);

      expect(find.text(MyPageStrings.historyTitle), findsOneWidget);
      // 목의 거래 4건이 그대로 다 보인다. 거르는 장치도, 더 보는 입구도 없다.
      expect(find.byType(TransactionTile), findsNWidgets(4));
      expect(find.text('-176,000 MSR'), findsOneWidget);
      expect(find.text('+150,000 MSR'), findsOneWidget);
      expect(find.text('09.12 19:42 · 양도 마켓'), findsOneWidget);
      expect(find.text(MyPageStrings.balanceAfter('23,400')), findsOneWidget);
      expect(find.text(AuthStrings.logout), findsOneWidget);
    });

    /// 로그아웃을 보려고 마이페이지를 내릴 일은 없어야 한다. 굴러도 되는 것은
    /// 코인 내역 목록 하나뿐이다.
    testWidgets('페이지는 굴리지 않고, 로그아웃은 내리지 않아도 보인다', (tester) async {
      await pumpMyPage(tester, loggedIn: true, api: _ManyTransactionsApi());
      await settle(tester);

      final scrollables = find.descendant(
        of: find.byType(MyPageScreen),
        matching: find.byType(Scrollable),
      );
      expect(scrollables, findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TransactionHistoryCard),
          matching: scrollables,
        ),
        findsOneWidget,
      );

      // 화면 안에 다 들어온다 — 끌어올리지 않고도 누를 수 있다.
      final logout = find.text(AuthStrings.logout);
      expect(logout, findsOneWidget);
      expect(
        tester.getRect(logout).bottom,
        lessThanOrEqualTo(
          tester.view.physicalSize.height / tester.view.devicePixelRatio,
        ),
      );
    });

    testWidgets('거래가 하나도 없으면 빈 상태 문구를 보여 준다', (tester) async {
      await pumpMyPage(tester, loggedIn: true, api: _EmptyWalletApi());
      await settle(tester);

      expect(find.byType(TransactionTile), findsNothing);
      expect(find.text(MyPageStrings.noTransactions), findsOneWidget);
    });

    /// 내역은 계속 쌓이는데 카드가 그만큼 길어지면 마이페이지가 한없이 늘어난다.
    /// 목록만 정해진 높이에서 자르고 그 안에서 굴린다.
    testWidgets('내역이 많아도 카드는 정해진 높이를 넘지 않고 그 안에서 스크롤된다', (tester) async {
      await pumpMyPage(tester, loggedIn: true, api: _ManyTransactionsApi());
      await settle(tester);

      final list = find.descendant(
        of: find.byType(TransactionHistoryCard),
        matching: find.byType(Scrollable),
      );
      expect(
        tester.getSize(list).height,
        lessThanOrEqualTo(MyPageMetrics.historyMaxHeight),
      );

      // 잘린 아래쪽도 굴리면 닿는다.
      final firstBefore = tester
          .widgetList<TransactionTile>(find.byType(TransactionTile))
          .first
          .transaction
          .title;
      await tester.drag(list, const Offset(0, -400));
      await tester.pumpAndSettle();
      final firstAfter = tester
          .widgetList<TransactionTile>(find.byType(TransactionTile))
          .first
          .transaction
          .title;
      expect(firstAfter, isNot(firstBefore));
    });

    testWidgets('실패하면 문구와 다시 시도가 보이고, 다시 시도하면 채워진다', (tester) async {
      final api = _FlakyMyPageApi(failuresBeforeSuccess: 1);
      await pumpMyPage(tester, loggedIn: true, api: api);
      await settle(tester);

      // 인사말과 지갑이 각자 실패를 알린다.
      expect(find.text(_FlakyMyPageApi.message), findsNWidgets(2));
      expect(find.text(AsyncBoundary.retryLabel), findsNWidgets(2));
      expect(find.text('123,000'), findsNothing);

      await tester.tap(find.text(AsyncBoundary.retryLabel).last);
      await settle(tester);
      expect(api.walletCalls, 2);
      expect(find.text('123,000'), findsOneWidget);
      expect(find.text(_FlakyMyPageApi.message), findsOneWidget);

      await tester.tap(find.text(AsyncBoundary.retryLabel));
      await settle(tester);
      expect(api.profileCalls, 2);
      expect(find.text(_FlakyMyPageApi.message), findsNothing);
      expect(
        find.textContaining(
          MockMyPageData.profile.nickname,
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('충전하기를 누르면 충전 화면이 열린다', (tester) async {
      await pumpMyPage(tester, loggedIn: true);
      await settle(tester);

      await tester.tap(find.text(MyPageStrings.charge));
      await tester.pumpAndSettle();

      expect(find.byType(CoinChargeScreen), findsOneWidget);
      expect(find.text(MyPageStrings.chargeTitle), findsOneWidget);
    });

    testWidgets('충전하고 돌아오면 잔액이 다시 받아져 늘어 있다', (tester) async {
      // 원장을 넘긴 목이라 충전이 다음 조회에도 남는다(앱의 목 서버와 같다).
      final ledger = MockWalletLedger();
      await pumpMyPage(
        tester,
        loggedIn: true,
        api: MockMyPageApi(latency: Duration.zero, ledger: ledger),
      );
      await settle(tester);
      expect(find.text('123,000'), findsOneWidget);

      await tester.tap(find.text(MyPageStrings.charge));
      await tester.pumpAndSettle();

      await tester.tap(find.text(MyPageStrings.withUnit('10,000')));
      await tester.pump();
      await tester.tap(find.text(MyPageStrings.chargeSubmit));
      await tester.pumpAndSettle();

      // 충전 화면은 닫히고, 성공 안내와 함께 새 잔액이 보인다.
      expect(find.byType(CoinChargeScreen), findsNothing);
      expect(
        find.text(toastText(MyPageStrings.chargeSucceeded('10,000'))),
        findsOneWidget,
      );
      expect(find.text('133,000'), findsOneWidget);
      expect(find.text('123,000'), findsNothing);
    });

    testWidgets('알림을 누르면 알림함이 열린다', (tester) async {
      await pumpMyPage(tester, loggedIn: true);
      await settle(tester);

      await tester.tap(find.byTooltip(MyPageStrings.notifications));
      await tester.pumpAndSettle();

      expect(find.text(notificationsLabel), findsOneWidget);
    });

    testWidgets('뒤로가기는 넘겨받은 콜백을 부른다', (tester) async {
      var backPressed = 0;
      await pumpMyPage(
        tester,
        loggedIn: true,
        onBackPressed: () => backPressed++,
      );
      await settle(tester);

      await tester.tap(find.byTooltip(MyPageStrings.back));
      expect(backPressed, 1);
    });

    testWidgets('로그아웃을 누르면 로그아웃 상태가 되며 서버에도 알린다', (tester) async {
      final session = await pumpMyPage(tester, loggedIn: true);
      await settle(tester);

      await tester.tap(find.text(AuthStrings.logout));
      await tester.pumpAndSettle();

      expect(session.isLoggedIn, isFalse);
      // 세션이 바뀌면 화면이 따라 바뀐다.
      expect(find.text(AuthStrings.login), findsOneWidget);
      expect(find.text(AuthStrings.logout), findsNothing);
      // 세션을 비우기 전에 꺼내 둔 리프레시 토큰이 서버로 갔다.
      expect(authApi.loggedOutWith, [MockAuthApi.tokens.refreshToken]);
    });

    testWidgets('서버에 못 알려도(연결 끊김) 로그아웃 상태가 된다', (tester) async {
      final session = await pumpMyPage(
        tester,
        loggedIn: true,
        tokens: offlineTokens,
      );
      await settle(tester);

      await tester.tap(find.text(AuthStrings.logout));
      await tester.pumpAndSettle();

      expect(session.isLoggedIn, isFalse);
      expect(find.text(AuthStrings.login), findsOneWidget);
      // 시도는 했다. 실패를 무시한 것이지 건너뛴 게 아니다.
      expect(authApi.loggedOutWith, [MockAuthApi.offlineRefreshToken]);
    });

    testWidgets('로그아웃하면 이 기기의 푸시 토큰도, 세션을 비우기 전에 지운다', (tester) async {
      final session = await pumpMyPage(tester, loggedIn: true);
      await settle(tester);

      await tester.tap(find.text(AuthStrings.logout));
      await tester.pumpAndSettle();

      expect(pushRegistrar.calls, 1);
      // 순서가 핵심이다. 세션을 먼저 비우면 해제 요청에 인증 헤더가 붙지 않아
      // 401 로 튕기고, 이 기기에 직전 회원의 알림이 계속 온다.
      expect(pushRegistrar.loggedInWhenCalled, isTrue);
      expect(session.isLoggedIn, isFalse);
    });
  });
}

/// 줄어든 거래만 있는 지갑. 필터의 빈 상태를 보는 데 쓴다.
/// 높이 제한을 보는 목. 카드가 담는 20건을 다 채운다.
class _ManyTransactionsApi implements MyPageApi {
  @override
  Future<MemberProfile> fetchProfile() => Future.value(MockMyPageData.profile);

  /// 예매자 실명은 결제 흐름만 쓴다. 이 목이 붙는 화면은 부르지 않는다.
  @override
  Future<String> fetchBookerName() => throw UnimplementedError();

  @override
  Future<WalletSummary> fetchWallet() => Future.value(
    WalletSummary(
      balance: 0,
      transactions: [
        for (var i = 0; i < MyPageMetrics.recentTransactionCount; i++)
          WalletTransaction(
            title: '거래 $i',
            amount: -1000 * (i + 1),
            balanceAfter: 0,
            occurredAt: DateTime(2026, 9, 15, 12, i),
            source: '양도 마켓',
          ),
      ],
    ),
  );

  @override
  Future<WalletSummary> charge(int amount) => throw UnimplementedError();
}

class _EmptyWalletApi implements MyPageApi {
  @override
  Future<MemberProfile> fetchProfile() => Future.value(MockMyPageData.profile);

  /// 예매자 실명은 결제 흐름만 쓴다. 이 목이 붙는 화면은 부르지 않는다.
  @override
  Future<String> fetchBookerName() => throw UnimplementedError();

  @override
  Future<WalletSummary> fetchWallet() =>
      Future.value(const WalletSummary(balance: 0, transactions: []));

  /// 이 목은 빈 상태만 본다. 충전은 쓰지 않는다.
  @override
  Future<WalletSummary> charge(int amount) => throw UnimplementedError();
}
