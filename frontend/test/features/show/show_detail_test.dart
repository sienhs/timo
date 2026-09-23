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
import 'package:timo/features/favorite/data/favorite_artist_store.dart';
import 'package:timo/features/favorite/data/favorite_store.dart';
import 'package:timo/features/favorite/constants.dart';
import 'package:timo/features/favorite/data/mock_favorite_api.dart';
import 'package:timo/features/favorite/state/favorite_scope.dart';
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
import 'package:timo/features/show/widgets/show_notice.dart';
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

  /// 상단 바 하트가 넣고 빼는 찜 목록. 공연 찜은 서버(목)에 남는다.
  late FavoriteStore favorites;

  /// 공연 찜을 들고 있는 가짜 서버.
  late MockFavoriteApi favoriteApi;

  ShowDetail detailOpening({
    Duration? after,
    ShowStatus? status,
    bool bookable = true,
    ShowBlockReason? blockReason,
    String title = '2026 아이유 콘서트',
    List<ZonePrice> zonePrices = const [
      ZonePrice(zoneName: '1층 A블록', price: 154000),
    ],
    List<String> imageUrls = const [],
  }) => ShowDetail(
    id: 1,
    title: title,
    venue: '고척스카이돔',
    // 단일 회차 공연이라 종료일을 읽지 않는다. 화면에는 하루로 찍힌다.
    startAt: DateTime(2026, 5, 20, 19),
    ticketOpenAt: after == null ? null : now.add(after),
    status:
        status ?? (after == null ? ShowStatus.onSale : ShowStatus.scheduled),
    bookable: bookable,
    blockReason: blockReason,
    zonePrices: zonePrices,
    artists: const [ShowArtist(name: '아이유')],
    imageUrls: imageUrls,
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

    favoriteApi = MockFavoriteApi();
    favorites = FavoriteStore(
      api: favoriteApi,
      artistStore: InMemoryFavoriteArtistStore(),
    );
    addTearDown(favorites.dispose);

    await tester.pumpWidget(
      AuthSessionScope(
        session: session,
        child: ShowApiScope(
          api: api ?? _FixedShowApi(detail),
          child: BookingApiScope(
            api: MockBookingApi(latency: Duration.zero),
            child: BookingScope(
              controller: controller,
              child: FavoriteScope(
                store: favorites,
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
                    AppRoutes.login: (_) =>
                        const Scaffold(body: Text('로그인 화면')),
                  },
                ),
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

    testWidgets('신청하면 버튼이 해제로 바뀌고, 다시 누르면 돌아온다', (tester) async {
      await pumpDetail(tester, detailOpening(after: const Duration(hours: 1)));

      await tester.tap(find.text(ShowDetailStrings.notifyAction));
      await tester.pump();
      await tester.pump(FavoriteLimits.toggleDebounce);

      expect(find.text(ShowDetailStrings.openAlarmOn), findsOneWidget);
      expect(find.text(ShowDetailStrings.unnotifyAction), findsOneWidget);
      expect(find.text(ShowDetailStrings.notifyAction), findsNothing);

      await tester.tap(find.text(ShowDetailStrings.unnotifyAction));
      await tester.pump();
      await tester.pump(FavoriteLimits.toggleDebounce);

      expect(find.text(ShowDetailStrings.openAlarmOff), findsOneWidget);
      expect(find.text(ShowDetailStrings.notifyAction), findsOneWidget);
    });

    // 아직 아무도 표를 갖고 있지 않아 올라올 매물이 없다.
    testWidgets('양도 마켓 알림 버튼은 세우지 않는다', (tester) async {
      await pumpDetail(tester, detailOpening(after: const Duration(hours: 1)));

      expect(find.text(ShowDetailStrings.marketAlarmAction), findsNothing);
    });
  });

  group('예매 중', () {
    testWidgets('양도 마켓 알림 버튼이 예매 버튼과 함께 선다', (tester) async {
      await pumpDetail(tester, detailOpening());

      expect(find.text(ShowDetailStrings.bookAction), findsOneWidget);
      expect(find.text(ShowDetailStrings.marketAlarmAction), findsOneWidget);
      // 오픈은 이미 했으니 오픈 알림을 신청할 자리가 아니다.
      expect(find.text(ShowDetailStrings.notifyAction), findsNothing);
    });

    testWidgets('신청하면 버튼이 해제로 바뀌고, 다시 누르면 돌아온다', (tester) async {
      await pumpDetail(tester, detailOpening());

      await tester.tap(find.text(ShowDetailStrings.marketAlarmAction));
      await tester.pump();

      expect(find.text(ShowDetailStrings.marketAlarmOn), findsOneWidget);
      expect(find.text(ShowDetailStrings.marketAlarmOffAction), findsOneWidget);

      await tester.tap(find.text(ShowDetailStrings.marketAlarmOffAction));
      await tester.pump();

      expect(find.text(ShowDetailStrings.marketAlarmOff), findsOneWidget);
      expect(find.text(ShowDetailStrings.marketAlarmAction), findsOneWidget);
      // 예매 버튼은 알림을 켜고 끄는 동안에도 자리를 지킨다.
      expect(find.text(ShowDetailStrings.bookAction), findsOneWidget);
    });
  });

  // 알림 신청은 찜과 별개다(백엔드 `AlarmController` — 찜을 하거나 풀어도 알림
  // 신청은 바뀌지 않는다). 하나를 눌러 다른 하나가 따라 움직이면 안 된다.
  group('찜과 알림', () {
    testWidgets('알림 버튼은 찜 목록을 건드리지 않는다', (tester) async {
      await pumpDetail(tester, detailOpening(after: const Duration(hours: 1)));

      await tester.tap(find.text(ShowDetailStrings.notifyAction));
      await tester.pump();
      await tester.pump(FavoriteLimits.toggleDebounce);

      expect(favorites.favorites.shows, isEmpty);
      expect(favoriteApi.wishedIds, isEmpty);
      expect(find.byTooltip(ShowDetailStrings.favoriteAction), findsOneWidget);
    });

    testWidgets('하트는 알림 버튼을 건드리지 않는다', (tester) async {
      await pumpDetail(tester, detailOpening(after: const Duration(hours: 1)));

      await tester.tap(find.byTooltip(ShowDetailStrings.favoriteAction));
      await tester.pump();
      await tester.pump(FavoriteLimits.toggleDebounce);
      // 하트는 화면부터 바꾸고 서버로는 조금 늦게 보낸다(연타 묶기).

      expect(favorites.favorites.hasShow(1), isTrue);
      expect(favoriteApi.wishedIds, [1]);
      expect(find.text(ShowDetailStrings.notifyAction), findsOneWidget);
      expect(find.text(ShowDetailStrings.openAlarmOn), findsNothing);
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
      // 사고팔 표가 없는 공연이라 알림도 세우지 않는다.
      expect(find.text(ShowDetailStrings.marketAlarmAction), findsNothing);
      expect(find.text(ShowDetailStrings.notifyAction), findsNothing);

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    // 잠긴 버튼이 이미 끝났다고 말한다. 그 위에 공연 날짜만 남으면 무슨 날인지
    // 헷갈린다(위쪽 '일시:' 줄에는 그대로 있다).
    testWidgets('하단 바에 공연 일시를 적지 않는다', (tester) async {
      await pumpDetail(tester, detailOpening(status: ShowStatus.closed));

      expect(
        find.text(ShowDetailStrings.periodLine('2026.05.20 (수) 19:00')),
        findsOneWidget,
      );
      expect(find.text('2026.05.20 (수) 19:00'), findsNothing);
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

    // 서버는 매진도 '예매 중이 아님(NOT_ON_SALE)' 으로 답한다. 그 말을 곧이
    // 들으면 매진 공연이 잠기는데, 취소표가 돌아올 수 있어 들어가 볼 이유가
    // 있다. 실제 응답과 같은 모양으로 먹여서 그 구분이 살아 있는지 본다.
    testWidgets('매진은 서버가 막았다고 해도 잠그지 않는다', (tester) async {
      await pumpDetail(
        tester,
        detailOpening(
          status: ShowStatus.soldOut,
          bookable: false,
          blockReason: ShowBlockReason.notOnSale,
        ),
      );

      expect(find.text(ShowDetailStrings.bookAction), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      // 매진이면 양도 매물을 기다리는 사람이 가장 많다. 취소표를 보러 가는
      // 길과 함께 선다.
      expect(find.text(ShowDetailStrings.marketAlarmAction), findsOneWidget);
    });
  });

  // 서버가 예매를 막았는데 시각만 봐서는 알 수 없는 경우들. 이게 없으면
  // 좌석을 다 고른 뒤 선점 단계에서야 막힌다.
  group('서버가 막은 공연', () {
    /// 오픈 시각은 지났는데 서버가 아직 열어 주지 않은 공연.
    /// (온체인 등록이 안 끝나 상태가 `SCHEDULED` 에 머문 경우)
    ShowDetail awaitingOpen() => detailOpening(
      after: const Duration(hours: -2),
      bookable: false,
      blockReason: ShowBlockReason.notOnSale,
    );

    testWidgets('오픈 시각이 지났어도 서버가 안 열었으면 예매로 못 들어간다', (tester) async {
      await pumpDetail(tester, awaitingOpen());

      expect(find.text(ShowDetailStrings.bookAction), findsNothing);
      expect(find.text(ShowDetailStrings.notifyAction), findsOneWidget);
      expect(find.text(ShowDetailStrings.upcomingBadge), findsOneWidget);
      expect(find.text(ShowDetailStrings.onSaleBadge), findsNothing);
    });

    // 언제 열릴지를 앱이 모른다. 남은 시간을 적으면 0 에 멈춘 시계가 된다.
    testWidgets('남은 시간은 적지 않는다', (tester) async {
      await pumpDetail(tester, awaitingOpen());

      expect(find.textContaining('오픈까지 남은 시간'), findsNothing);
    });

    testWidgets('마감된 공연은 버튼을 잠그고 마감이라고 적는다', (tester) async {
      await pumpDetail(
        tester,
        detailOpening(
          bookable: false,
          blockReason: ShowBlockReason.bookingClosed,
        ),
      );

      expect(find.text(ShowDetailStrings.bookingClosedNotice), findsOneWidget);
      expect(find.text(ShowDetailStrings.bookAction), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });

    // 마감은 공연이 아직 남아 있는 구간이다. '종료' 가 붙으면 그날 저녁
    // 공연을 보러 갈 사람이 공연이 없어진 줄 안다.
    testWidgets('마감을 종료라고 적지 않는다', (tester) async {
      await pumpDetail(
        tester,
        detailOpening(
          bookable: false,
          blockReason: ShowBlockReason.bookingClosed,
        ),
      );

      expect(find.text(ShowDetailStrings.closedNotice), findsNothing);
      expect(find.text(ShowDetailStrings.onSaleBadge), findsNothing);
      expect(find.text(ShowDetailStrings.upcomingBadge), findsNothing);
    });
  });

  group('오픈 후', () {
    testWidgets('예매 버튼만 세우고 그 위에 공연 일시를 겹쳐 적지 않는다', (tester) async {
      await pumpDetail(tester, detailOpening());

      expect(find.text(ShowDetailStrings.onSaleBadge), findsOneWidget);
      expect(find.text(ShowDetailStrings.bookAction), findsOneWidget);
      // 공연 일시는 위쪽 '일시:' 줄 한 곳에만 있다. 버튼 바로 위에 또 찍으면
      // 예매 마감일처럼 읽힌다.
      expect(
        find.text(ShowDetailStrings.periodLine('2026.05.20 (수) 19:00')),
        findsOneWidget,
      );
      expect(find.text('2026.05.20 (수) 19:00'), findsNothing);
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
    // 날짜만 적으면 그날 몇 시에 가야 하는지 알 길이 없다.
    expect(find.text('일시: 2026.05.20 (수) 19:00'), findsOneWidget);
    expect(find.text(ShowDetailStrings.zonePriceSection), findsOneWidget);
    expect(find.text('1층 A블록'), findsOneWidget);
    expect(find.text('154,000원'), findsOneWidget);
    expect(find.text(ShowDetailStrings.artistSection), findsOneWidget);
    expect(find.text('아이유'), findsOneWidget);
  });

  testWidgets('안내 이미지가 없으면 NOTICE 에 공통 규정을 적는다', (tester) async {
    await pumpDetail(tester, detailOpening());

    await tester.scrollUntilVisible(
      find.text(ShowDetailStrings.noticeSection),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    // 자리를 접지 않는다. 예매 마감·양도·환불은 이미지 유무와 무관하다.
    expect(find.text(ShowDetailStrings.noticeSection), findsOneWidget);
    for (final line in ShowDetailStrings.defaultNoticeLines) {
      expect(find.text(line), findsOneWidget);
    }
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('NOTICE 이미지를 서버 순서대로 표시한다', (tester) async {
    await pumpDetail(
      tester,
      detailOpening(
        imageUrls: const [
          'https://example.com/first.jpg',
          'https://example.com/second.jpg',
        ],
      ),
    );

    await tester.scrollUntilVisible(
      find.text(ShowDetailStrings.noticeSection),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text(ShowDetailStrings.noticeSection), findsOneWidget);
    // 이미지가 있으면 공통 규정은 물러난다 - 주최사 안내가 우선이다.
    expect(find.text(ShowDetailStrings.defaultNoticeLines.first), findsNothing);
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images.map((image) => (image.image as NetworkImage).url), [
      'https://example.com/first.jpg',
      'https://example.com/second.jpg',
    ]);
    expect(images.every((image) => image.fit == BoxFit.fitWidth), isTrue);
  });

  testWidgets('NOTICE 이미지 로딩과 실패 문구를 표시한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ShowNotice(imageUrls: ['https://example.com/a.jpg']),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final loading = image.loadingBuilder!(
      tester.element(find.byType(Image)),
      const SizedBox(),
      const ImageChunkEvent(cumulativeBytesLoaded: 1, expectedTotalBytes: 2),
    );
    final error = image.errorBuilder!(
      tester.element(find.byType(Image)),
      Exception('load failed'),
      null,
    );

    expect(loading, isA<Center>());
    expect(error, isA<Center>());
    expect(
      (loading as Center).child,
      isA<Text>().having(
        (text) => text.data,
        'message',
        ShowDetailStrings.noticeImageLoading,
      ),
    );
    expect(
      (error as Center).child,
      isA<Text>().having(
        (text) => text.data,
        'message',
        ShowDetailStrings.noticeImageError,
      ),
    );
  });

  group('찜', () {
    testWidgets('하트를 누르면 찜 목록에 들어가고, 다시 누르면 빠진다', (tester) async {
      await pumpDetail(tester, detailOpening());

      await tester.tap(find.byTooltip(ShowDetailStrings.favoriteAction));
      await tester.pump();
      await tester.pump(FavoriteLimits.toggleDebounce);

      expect(favorites.favorites.hasShow(1), isTrue);
      expect(favoriteApi.wishedIds, [1]);
      expect(favorites.favorites.shows.single.title, '2026 아이유 콘서트');
      expect(favorites.favorites.shows.single.isOnSale, isTrue);
      expect(
        find.byTooltip(ShowDetailStrings.unfavoriteAction),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip(ShowDetailStrings.unfavoriteAction));
      await tester.pump();
      await tester.pump(FavoriteLimits.toggleDebounce);

      expect(favorites.favorites.shows, isEmpty);
      expect(find.byTooltip(ShowDetailStrings.favoriteAction), findsOneWidget);
    });

    // 찜은 서버에 남으므로 로그인해야 한다. 안내만 띄우고 하트는 빈 채로 둔다.
    testWidgets('로그아웃 상태면 찜하지 않고 로그인하라고 알린다', (tester) async {
      await pumpDetail(
        tester,
        detailOpening(after: const Duration(hours: 1)),
        loggedIn: false,
      );

      await tester.tap(find.byTooltip(ShowDetailStrings.favoriteAction));
      await tester.pump();
      await tester.pump(FavoriteLimits.toggleDebounce);

      expect(favorites.favorites.shows, isEmpty);
      expect(find.text(FavoriteStrings.loginRequired), findsOneWidget);
      expect(find.byTooltip(ShowDetailStrings.favoriteAction), findsOneWidget);
    });

    testWidgets('끝난 공연은 판매 종료로 남는다', (tester) async {
      await pumpDetail(tester, detailOpening(status: ShowStatus.closed));

      await tester.tap(find.byTooltip(ShowDetailStrings.favoriteAction));
      await tester.pump();
      await tester.pump(FavoriteLimits.toggleDebounce);

      expect(favorites.favorites.shows.single.isOnSale, isFalse);
    });
  });

  group('아직 없는 화면', () {
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
        // 로딩 화면을 건너뛰고 홈에서 시작한다.
        initialRoute: AppRoutes.home,
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
    // 스크롤은 카드가 '보이기 시작하면' 멈춘다. 배너가 커지면서 카드가 화면
    // 끝에 걸친 채로 멈추는 일이 생겨, 누를 수 있는 자리까지 마저 올린다.
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(find.byType(ShowDetailScreen), findsOneWidget);
    // 누른 공연의 상세가 열려야 한다. 홈 카드가 넘긴 공연 번호로 찾는다.
    expect(find.text('2026 아이유 콘서트'), findsOneWidget);
    expect(find.text(ShowDetailStrings.bookAction), findsOneWidget);
  });
}
