import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/app.dart';
import 'package:timo/core/network/api_exception.dart';
import 'package:timo/core/theme/app_theme.dart';
import 'package:timo/core/widgets/async_boundary.dart';
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
import 'package:timo/features/show/data/mock_show_api.dart';
import 'package:timo/features/show/data/show_api.dart';
import 'package:timo/features/show/state/show_api_scope.dart';
import 'package:timo/features/show/models/show_artist.dart';
import 'package:timo/features/show/models/show_detail.dart';
import 'package:timo/features/show/models/zone_price.dart';
import 'package:timo/features/show/screens/show_detail_screen.dart';
import 'package:timo/routes/app_routes.dart';

/// 정해진 공연 하나만 돌려주는 가짜 API.
///
/// 화면이 스스로 조회하게 되면서 필요해졌다. 상태별 화면을 보려면 그 상태의
/// 공연을 먹여야 하는데, 목 데이터에 없는 조합(끝난 공연 등)도 봐야 한다.
class _FixedShowApi implements ShowApi {
  const _FixedShowApi(this.detail);

  final ShowDetail detail;

  @override
  Future<ShowDetail> fetchShowDetail(int concertId) async => detail;
}

/// 늘 실패하는 가짜 API. 실패 화면을 보려고 쓴다.
class _FailingShowApi implements ShowApi {
  const _FailingShowApi(this.message);

  final String message;

  @override
  Future<ShowDetail> fetchShowDetail(int concertId) async =>
      throw ApiException(message, status: 404);
}

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

  ShowDetail detailOpening({
    Duration? after,
    ShowStatus? status,
    String title = '2026 아이유 콘서트',
    List<ZonePrice> zonePrices = const [
      ZonePrice(zoneName: '1층 A블록', price: 154000),
    ],
  }) => ShowDetail(
    id: 1,
    title: title,
    venue: '고척스카이돔',
    // 단일 회차 공연이라 종료일을 읽지 않는다. 화면에는 하루로 찍힌다.
    startAt: DateTime(2026, 5, 20),
    ticketOpenAt: after == null ? null : now.add(after),
    status:
        status ?? (after == null ? ShowStatus.onSale : ShowStatus.scheduled),
    zonePrices: zonePrices,
    artists: const [ShowArtist(name: '아이유')],
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
    ShowApi? api,
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
        child: ShowApiScope(
          api: api ?? _FixedShowApi(detail),
          child: BookingApiScope(
            api: MockBookingApi(latency: Duration.zero),
            child: BookingScope(
              controller: controller,
              child: MaterialApp(
                theme: AppTheme.light,
                home: ShowDetailScreen(
                  showId: detail.id,
                  clock: clock ?? () => now,
                ),
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
      ),
    );
    // 한 번은 조회 결과를 받는 프레임, 한 번은 그 결과를 그리는 프레임이다.
    await tester.pump();
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

  group('끝난 공연', () {
    testWidgets('예매 버튼이 잠기고 그 자리에 이유가 찍힌다', (tester) async {
      await pumpDetail(tester, detailOpening(status: ShowStatus.closed));

      expect(find.text(ShowDetailStrings.closedNotice), findsOneWidget);
      expect(find.text(ShowDetailStrings.bookAction), findsNothing);

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    // 잠긴 버튼이 이미 끝났다고 말한다. 그 위에 공연 날짜만 남으면 무슨 날인지
    // 헷갈린다(위쪽 '일시:' 줄에는 그대로 있다).
    testWidgets('하단 바에 공연 날짜를 적지 않는다', (tester) async {
      await pumpDetail(tester, detailOpening(status: ShowStatus.closed));

      expect(find.text('2026.05.20'), findsNothing);
      expect(
        find.text(ShowDetailStrings.periodLine('2026.05.20')),
        findsOneWidget,
      );
    });

    testWidgets('취소된 공연도 같이 잠근다', (tester) async {
      await pumpDetail(tester, detailOpening(status: ShowStatus.canceled));

      expect(find.text(ShowDetailStrings.canceledNotice), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });

    // 오픈 시각은 이미 지났으니 판정만 보면 '예매중' 이 된다. 끝난 공연에
    // 그 말이 붙으면 거짓말이라 뱃지를 아예 달지 않는다.
    testWidgets('예매중 뱃지를 달지 않는다', (tester) async {
      await pumpDetail(tester, detailOpening(status: ShowStatus.closed));

      expect(find.text(ShowDetailStrings.onSaleBadge), findsNothing);
      expect(find.text(ShowDetailStrings.upcomingBadge), findsNothing);
    });

    testWidgets('매진은 잠그지 않는다', (tester) async {
      await pumpDetail(tester, detailOpening(status: ShowStatus.soldOut));

      // 취소표가 돌아올 수 있어 들어가 볼 이유가 있다.
      expect(find.text(ShowDetailStrings.bookAction), findsOneWidget);
    });
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

    // 예매 화면 머리말이 상세와 다른 공연을 가리키면, 무엇을 예매하는지 모른 채
    // 좌석을 고르게 된다. 예매 컨트롤러는 목 공연(아이유)으로 세워 두고, 상세가
    // 넘긴 공연으로 바뀌는지 본다.
    testWidgets('예매로 들어가면 그 공연이 예매 화면 머리말에 올라간다', (tester) async {
      await pumpDetail(tester, detailOpening(title: '검정치마 단독공연 : 401'));

      await tester.tap(find.text(ShowDetailStrings.bookAction));
      await tester.pumpAndSettle();

      expect(find.text('검정치마 단독공연 : 401'), findsOneWidget);
      expect(find.text(MockBookingData.performance.title), findsNothing);
    });
  });

  group('가격', () {
    testWidgets('구역별로 한 줄씩 낸다', (tester) async {
      await pumpDetail(
        tester,
        detailOpening(
          zonePrices: const [
            ZonePrice(zoneName: '1층 A블록', price: 150000),
            ZonePrice(zoneName: '2층 C블록', price: 120000),
          ],
        ),
      );

      expect(find.text('1층 A블록'), findsOneWidget);
      expect(find.text('150,000원'), findsOneWidget);
      expect(find.text('2층 C블록'), findsOneWidget);
      expect(find.text('120,000원'), findsOneWidget);
    });

    // 가격은 구역 조회에서 오는데 그 조회는 로그인해야 열린다. 못 받았으면
    // 빈 카드를 세우는 대신 자리를 접는다.
    testWidgets('못 받았으면 가격 칸을 접는다', (tester) async {
      await pumpDetail(tester, detailOpening(zonePrices: const []));

      expect(find.text(ShowDetailStrings.zonePriceSection), findsNothing);
      // 나머지는 그대로 나온다.
      expect(find.text('2026 아이유 콘서트'), findsOneWidget);
      expect(find.text(ShowDetailStrings.artistSection), findsOneWidget);
    });
  });

  testWidgets('공연을 못 불러오면 서버 문구와 다시 시도가 나온다', (tester) async {
    await pumpDetail(
      tester,
      detailOpening(),
      api: _FailingShowApi('공연을 찾을 수 없습니다.'),
    );

    expect(find.text('공연을 찾을 수 없습니다.'), findsOneWidget);
    expect(find.text(AsyncBoundary.retryLabel), findsOneWidget);
  });

  testWidgets('공연 정보와 안내를 시안 순서대로 보여 준다', (tester) async {
    await pumpDetail(tester, detailOpening());

    expect(find.text('2026 아이유 콘서트'), findsOneWidget);
    expect(find.text('공연 장소: 고척스카이돔'), findsOneWidget);
    expect(find.text('일시: 2026.05.20'), findsOneWidget);
    expect(find.text(ShowDetailStrings.zonePriceSection), findsOneWidget);
    expect(find.text('1층 A블록'), findsOneWidget);
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
      const App(
        homeApi: MockHomeApi(latency: Duration.zero),
        showApi: MockShowApi(latency: Duration.zero),
      ),
    );
    await tester.pumpAndSettle();

    // 이미 오픈한 공연을 고른다. 오픈 전 공연은 남은 시간을 1초마다 다시
    // 그려서 `pumpAndSettle` 이 영원히 정착하지 않는다.
    final card = find.widgetWithText(ShowPosterCard, '2026 아이유 콘서트');
    // 인기 공연 줄은 첫 화면 아래에 있다. 세로 목록을 끌어 올려야 카드가 만들어진다.
    await tester.scrollUntilVisible(
      card,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(find.byType(ShowDetailScreen), findsOneWidget);
    // 누른 공연의 상세가 열려야 한다. 홈 카드가 넘긴 공연 번호로 찾는다.
    expect(find.text('2026 아이유 콘서트'), findsOneWidget);
    expect(find.text(ShowDetailStrings.bookAction), findsOneWidget);
  });
}
