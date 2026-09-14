import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/app.dart';
import 'package:timo/core/theme/app_theme.dart';
import 'package:timo/features/auth/models/auth_tokens.dart';
import 'package:timo/features/auth/data/token_storage.dart';
import 'package:timo/features/auth/state/auth_session.dart';
import 'package:timo/features/auth/state/auth_session_scope.dart';
import 'package:timo/features/booking/constants.dart';
import 'package:timo/features/booking/data/mock_booking_api.dart';
import 'package:timo/features/booking/data/mock_booking_data.dart';
import 'package:timo/features/booking/state/booking_api_scope.dart';
import 'package:timo/features/booking/screens/zone_selection_screen.dart';
import 'package:timo/features/booking/state/booking_controller.dart';
import 'package:timo/features/booking/state/booking_scope.dart';
import 'package:timo/features/home/data/mock_home_api.dart';
import 'package:timo/features/home/widgets/show_poster_card.dart';
import 'package:timo/features/show/constants.dart';
import 'package:timo/features/show/models/seat_price.dart';
import 'package:timo/features/show/models/show_artist.dart';
import 'package:timo/features/show/models/show_detail.dart';
import 'package:timo/features/show/screens/show_detail_screen.dart';
import 'package:timo/routes/app_routes.dart';

/// 공연 상세 화면.
///
/// 이 화면에서 실제로 갈리는 것은 **예매 상태 하나**다. 그래서 상태별로
/// 무엇이 보이고 어디로 가는지만 본다. 픽셀 값은 시안이 바뀌면 같이 바뀌므로
/// 테스트로 굳히지 않는다.
void main() {
  /// 360 x 800 dp
  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// 기준 시각. 실제 시계를 쓰면 카운트다운 문구가 실행할 때마다 달라진다.
  final now = DateTime(2026, 5, 1, 10);

  ShowDetail detailOpening({Duration? after}) => ShowDetail(
    id: 'iu-2026',
    title: '2026 아이유 콘서트',
    venue: '고척스카이돔',
    posterAsset: 'assets/images/sample_poster.jpg',
    // 단일 회차 공연이라 종료일이 없다. 화면에는 하루로 찍힌다.
    startAt: DateTime(2026, 5, 20),
    ticketOpenAt: after == null ? null : now.add(after),
    seatPrices: const [SeatPrice(grade: '모든 좌석', price: 154000)],
    artists: const [ShowArtist(name: '아이유')],
    notice: const ['본 공연은 포인트로만 결제하실 수 있습니다.'],
  );

  /// 화면을 단독으로 띄운다. [clock] 을 주면 그 시계로 시간이 흐른다.
  ///
  /// `pumpAndSettle` 을 쓰지 않는다 — 오픈 전 공연은 1초마다 남은 시간을
  /// 다시 그려서 영원히 '정착'하지 않는다.
  /// 로그인 상태를 만드는 토큰.
  const tokens = AuthTokens(
    memberId: 1,
    accessToken: 'test-access-token',
    refreshToken: 'test-refresh-token',
    accessTokenExpiresIn: Duration(minutes: 30),
  );

  Future<void> pumpDetail(
    WidgetTester tester,
    ShowDetail detail, {
    DateTime Function()? clock,
    bool loggedIn = true,
  }) async {
    usePhoneSize(tester);
    // 좌석 선택 화면은 예매 컨트롤러와 예매 API 를 위에서 받는다. 앱에서는
    // App 이 내려주므로, 단독으로 띄울 때는 여기서 같은 것을 세워 준다.
    final controller = BookingController(
      performance: MockBookingData.performance,
    );
    addTearDown(controller.dispose);

    // 예매 진입은 로그인을 요구한다. 로그인 여부를 보는 화면이므로 세션도
    // 세워 준다. 기본은 로그인 상태다 — 이 파일의 관심사는 예매 진입 자체가
    // 아니라 상세 화면의 표시이고, 로그인 분기는 따로 검사한다.
    final session = AuthSession(storage: InMemoryTokenStorage());
    if (loggedIn) await session.signIn(tokens);
    addTearDown(session.dispose);

    await tester.pumpWidget(
      AuthSessionScope(
        session: session,
        child: BookingApiScope(
          api: MockBookingApi(latency: Duration.zero),
          child: BookingScope(
            controller: controller,
            child: MaterialApp(
              theme: AppTheme.light,
              home: ShowDetailScreen(detail: detail, clock: clock ?? () => now),
              // 예매 버튼이 실제로 좌석 선택으로 가는지 보려면 목적지가 필요하다.
              routes: {
                AppRoutes.zoneSelection: (_) => const ZoneSelectionScreen(
                  concertId: BookingConstants.fallbackConcertId,
                ),
                AppRoutes.login: (_) => const Scaffold(body: Text('로그인 화면')),
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('오픈 전', () {
    testWidgets('하루 안쪽이면 남은 시간을 초까지 세고 알림 버튼을 준다', (tester) async {
      await pumpDetail(
        tester,
        detailOpening(after: const Duration(hours: 3, minutes: 12)),
      );

      expect(find.text(ShowDetailStrings.upcomingBadge), findsOneWidget);
      expect(find.text('오픈까지 남은 시간 03:12:00'), findsOneWidget);
      expect(find.text(ShowDetailStrings.notifyAction), findsOneWidget);
      expect(find.text(ShowDetailStrings.bookAction), findsNothing);
    });

    testWidgets('하루가 넘으면 초를 세지 않고 오픈 일시를 적는다', (tester) async {
      await pumpDetail(
        tester,
        detailOpening(after: const Duration(days: 5, hours: 4)),
      );

      expect(find.text('2026.05.06 14:00 오픈'), findsOneWidget);
      expect(find.text(ShowDetailStrings.notifyAction), findsOneWidget);
    });

    testWidgets('알림 버튼은 준비 중이라고 알려 준다', (tester) async {
      await pumpDetail(tester, detailOpening(after: const Duration(hours: 1)));

      await tester.tap(find.text(ShowDetailStrings.notifyAction));
      await tester.pump();

      expect(find.text(ShowDetailStrings.notifyNotReady), findsOneWidget);
    });
  });

  testWidgets('오픈 시각이 지나면 화면을 다시 열지 않아도 예매 버튼으로 바뀐다', (tester) async {
    var fakeNow = now;
    await pumpDetail(
      tester,
      detailOpening(after: const Duration(seconds: 3)),
      clock: () => fakeNow,
    );

    expect(find.text('오픈까지 남은 시간 00:00:03'), findsOneWidget);

    // 시계를 1초씩 밀면서 같은 만큼 프레임을 넘긴다.
    for (var second = 0; second < 3; second++) {
      fakeNow = fakeNow.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }

    expect(find.text(ShowDetailStrings.bookAction), findsOneWidget);
    expect(find.text(ShowDetailStrings.notifyAction), findsNothing);
    // 하단 바만 바뀌고 상단 뱃지가 그대로 남으면 상태가 두 개로 보인다.
    expect(find.text(ShowDetailStrings.onSaleBadge), findsOneWidget);
    expect(find.text(ShowDetailStrings.upcomingBadge), findsNothing);
  });

  group('오픈 후', () {
    testWidgets('공연 기간과 예매 버튼을 보여 준다', (tester) async {
      await pumpDetail(tester, detailOpening());

      expect(find.text(ShowDetailStrings.onSaleBadge), findsOneWidget);
      expect(find.text('2026.05.20'), findsOneWidget);
      expect(find.text(ShowDetailStrings.bookAction), findsOneWidget);
    });

    testWidgets('예매 버튼이 좌석 선택으로 보낸다', (tester) async {
      await pumpDetail(tester, detailOpening());

      await tester.tap(find.text(ShowDetailStrings.bookAction));
      await tester.pumpAndSettle();

      expect(find.byType(ZoneSelectionScreen), findsOneWidget);
    });
  });

  testWidgets('공연 정보와 안내를 시안 순서대로 보여 준다', (tester) async {
    await pumpDetail(tester, detailOpening());

    expect(find.text('2026 아이유 콘서트'), findsOneWidget);
    expect(find.text('공연 장소: 고척스카이돔'), findsOneWidget);
    expect(find.text('일시: 2026.05.20'), findsOneWidget);
    expect(find.text(ShowDetailStrings.seatPriceSection), findsOneWidget);
    expect(find.text('모든 좌석'), findsOneWidget);
    expect(find.text('154,000원'), findsOneWidget);
    expect(find.text(ShowDetailStrings.artistSection), findsOneWidget);
    expect(find.text('아이유'), findsOneWidget);
    expect(find.text(ShowDetailStrings.noticeSection), findsOneWidget);
  });

  group('아직 없는 화면', () {
    testWidgets('찜하기는 준비 중이라고 알려 준다', (tester) async {
      await pumpDetail(tester, detailOpening());

      await tester.tap(find.byTooltip(ShowDetailStrings.favoriteAction));
      await tester.pump();

      expect(find.text(ShowDetailStrings.favoriteNotReady), findsOneWidget);
    });

    testWidgets('공유 버튼은 아직 달지 않는다', (tester) async {
      await pumpDetail(tester, detailOpening());

      // 공유할 링크가 없어 뺐다. 시안에는 있으므로 되살아나지 않게 못을 박는다.
      expect(find.byIcon(Icons.share_outlined), findsNothing);
    });
  });

  testWidgets('홈 카드를 누르면 상세가 열린다', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      const App(homeApi: MockHomeApi(latency: Duration.zero)),
    );
    await tester.pumpAndSettle();

    // 홈 카드는 서버 공연 id 를 넘기는데 상세는 아직 목업이라 그 id 를 모른다.
    // 표본 공연(이미 오픈)으로 대체되므로 카운트다운 없이 정착한다. 상세 API
    // 를 붙이면 누른 공연의 상세가 열리는지로 바꾼다.
    await tester.tap(find.byType(ShowPosterCard).first);
    await tester.pumpAndSettle();

    expect(find.byType(ShowDetailScreen), findsOneWidget);
    expect(find.text(ShowDetailStrings.bookAction), findsOneWidget);
  });
}
