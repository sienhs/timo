import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/app.dart';
import 'package:timo/core/network/api_exception.dart';
import 'package:timo/core/widgets/async_boundary.dart';
import 'package:timo/features/auth/data/token_storage.dart';
import 'package:timo/features/auth/models/auth_tokens.dart';
import 'package:timo/features/auth/state/auth_session.dart';
import 'package:timo/features/favorite/constants.dart';
import 'package:timo/features/favorite/data/favorite_artist_store.dart';
import 'package:timo/features/favorite/data/favorite_store.dart';
import 'package:timo/features/favorite/data/mock_favorite_api.dart';
import 'package:timo/features/favorite/models/favorite_artist.dart';
import 'package:timo/features/home/constants.dart';
import 'package:timo/features/home/data/home_api.dart';
import 'package:timo/features/home/data/mock_home_api.dart';
import 'package:timo/features/home/data/mock_home_data.dart';
import 'package:timo/features/home/data/recent_search_store.dart';
import 'package:timo/features/home/models/artist_summary.dart';
import 'package:timo/features/home/models/show_summary.dart';
import 'package:timo/features/home/models/trending_keyword.dart';
import 'package:timo/features/home/screens/show_search_screen.dart';
import 'package:timo/features/home/widgets/recent_search_chips.dart';
import 'package:timo/features/home/widgets/recommended_artist_row.dart';
import 'package:timo/features/home/widgets/related_artist_row.dart';
import 'package:timo/features/home/widgets/show_banner_card.dart';
import 'package:timo/features/home/widgets/trending_keyword_list.dart';
import 'package:timo/features/shell/constants.dart';
import 'package:timo/features/shell/screens/main_shell_screen.dart';
import 'package:timo/features/shell/widgets/app_bottom_nav_bar.dart';
import 'package:timo/features/show/data/mock_show_api.dart';
import 'package:timo/features/show/screens/show_detail_screen.dart';
import 'package:timo/routes/app_routes.dart';

/// 공연 검색 화면. 홈에서 들어가 '무엇이 보이는가' 와 '누르면 어디로 가는가' 만
/// 본다. 픽셀 값은 시안이 바뀌면 같이 바뀌므로 테스트로 굳히지 않는다.
void main() {
  /// 인기 검색어 집계 시각을 고정한다. 목은 이 시각을 정시로 내린다.
  final now = DateTime(2026, 9, 4, 13, 20);

  late InMemoryRecentSearchStore store;

  /// 하트가 넣고 빼는 찜 목록. 공연은 서버(목), 아티스트는 기기에 남는다.
  late FavoriteStore favorites;

  /// 공연 찜을 들고 있는 가짜 서버.
  late MockFavoriteApi favoriteApi;

  /// 로그인 상태를 만드는 토큰. 공연 찜은 로그인해야 된다.
  const tokens = AuthTokens(
    memberId: 1,
    accessToken: 'test-access-token',
    refreshToken: 'test-refresh-token',
    accessTokenExpiresIn: Duration(minutes: 30),
  );

  /// 360 x 800 dp
  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// 홈에서 검색 바를 눌러 검색 화면까지 간다. [recent] 는 기기에 저장돼 있던
  /// 최근 검색어다.
  Future<void> pumpSearch(
    WidgetTester tester, {
    HomeApi? api,
    List<String>? recent,
    bool loggedIn = true,
  }) async {
    usePhoneSize(tester);
    store = InMemoryRecentSearchStore(recent);
    favoriteApi = MockFavoriteApi();
    favorites = FavoriteStore(
      api: favoriteApi,
      artistStore: InMemoryFavoriteArtistStore(),
    );
    addTearDown(favorites.dispose);
    // 공연 하트는 서버에 남으므로 로그인 상태가 기본이다. 로그아웃 분기는
    // 따로 검사한다.
    final session = AuthSession(storage: InMemoryTokenStorage());
    if (loggedIn) await session.signIn(tokens);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      App(
        // 로딩 화면을 건너뛰고 홈에서 시작한다.
        initialRoute: AppRoutes.home,
        session: session,
        homeApi: api ?? MockHomeApi(latency: Duration.zero, clock: () => now),
        recentSearchStore: store,
        favoriteStore: favorites,
        // 검색 결과를 누르면 공연 상세가 열린다. 목을 안 꽂으면 진짜 서버로
        // 요청이 나간다.
        showApi: const MockShowApi(latency: Duration.zero),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(HomeStrings.searchHint));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester, String keyword) async {
    await tester.enterText(find.byType(TextField), keyword);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  Finder inChips(String keyword) => find.descendant(
    of: find.byType(RecentSearchChips),
    matching: find.text(keyword),
  );

  group('검색 전', () {
    testWidgets('추천 검색어와 실시간 인기 검색어가 집계 시각과 함께 보인다', (tester) async {
      await pumpSearch(tester);

      expect(find.text(HomeStrings.recommendedSection), findsOneWidget);
      for (final artist in MockHomeData.recommendedArtists) {
        // 사진이 없는 아티스트는 아바타에 이름 첫 글자를 찍는다. 한 글자
        // 이름('뷔')은 그 글자와 이름표가 같아 둘이 잡히므로 '하나 이상' 으로 본다.
        expect(
          find.descendant(
            of: find.byType(RecommendedArtistRow),
            matching: find.text(artist.name),
          ),
          findsAtLeastNWidgets(1),
        );
      }

      expect(find.text(HomeStrings.trendingSection), findsOneWidget);
      expect(
        find.text(HomeStrings.trendingAsOf(DateTime(2026, 9, 4, 13))),
        findsOneWidget,
      );
      // 목록 전체가 한 화면에 안 들어가도 다 만들어져 있는지 첫 줄·끝 줄로 본다.
      expect(find.text('RESCENE'), findsOneWidget);
      expect(find.text('레드벨벳'), findsOneWidget);
    });

    testWidgets('등락은 색만이 아니라 상승·하락 라벨이 붙은 아이콘이다', (tester) async {
      await pumpSearch(tester);

      bool hasLabel(Widget widget, String label) =>
          widget is Icon && widget.semanticLabel == label;
      final ups = MockHomeData.trendingKeywords
          .where((k) => k.trend == KeywordTrend.up)
          .length;
      final downs = MockHomeData.trendingKeywords
          .where((k) => k.trend == KeywordTrend.down)
          .length;

      expect(
        find.byWidgetPredicate((w) => hasLabel(w, HomeStrings.trendingUp)),
        findsNWidgets(ups),
      );
      expect(
        find.byWidgetPredicate((w) => hasLabel(w, HomeStrings.trendingDown)),
        findsNWidgets(downs),
      );
    });

    testWidgets('저장된 최근 검색어가 없으면 섹션 자체가 없다', (tester) async {
      await pumpSearch(tester);

      expect(find.text(HomeStrings.recentSection), findsNothing);
      expect(find.byType(RecentSearchChips), findsNothing);
    });

    testWidgets('저장된 최근 검색어가 칩으로 보인다', (tester) async {
      await pumpSearch(tester, recent: ['아이유', '빅뱅']);

      expect(find.text(HomeStrings.recentSection), findsOneWidget);
      expect(inChips('아이유'), findsOneWidget);
      expect(inChips('빅뱅'), findsOneWidget);
    });
  });

  group('검색 실행', () {
    testWidgets('제출하면 예매중·오픈 예정 공연이 큰 카드로 나오고 최근 검색어에 남는다', (tester) async {
      await pumpSearch(tester);

      await submit(tester, '콘서트');

      // '콘서트' 가 제목에 든 공연은 아이유·김준수 둘이고 둘 다 예매중이다.
      expect(find.text(HomeStrings.resultSection), findsOneWidget);
      expect(find.byType(ShowBannerCard), findsNWidgets(2));
      expect(find.text(MockHomeApi.iu.title), findsOneWidget);
      expect(find.text(MockHomeApi.iu.venueName), findsOneWidget);
      expect(find.text(MockHomeApi.xia.title), findsOneWidget);
      expect(store.keywords, ['콘서트']);
    });

    testWidgets('종료된 공연은 검색에 잡혀도 섹션에서 걸러진다', (tester) async {
      await pumpSearch(tester);

      await submit(tester, '페기구');

      expect(MockHomeApi.peggyGou.isOpenOrUpcoming, isFalse);
      expect(find.byType(ShowBannerCard), findsNothing);
      expect(find.text(HomeStrings.searchEmpty('페기구')), findsOneWidget);
    });

    testWidgets('이름이 맞는 관련 아티스트가 보이고, 없으면 섹션이 없다', (tester) async {
      await pumpSearch(tester);

      await submit(tester, '아이유');
      expect(find.text(HomeStrings.relatedArtistSection), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(RelatedArtistRow),
          matching: find.text('아이유'),
        ),
        findsOneWidget,
      );

      await submit(tester, '콘서트');
      expect(find.text(HomeStrings.relatedArtistSection), findsNothing);
      expect(find.byType(RelatedArtistRow), findsNothing);
    });

    testWidgets('최근 검색어 칩을 누르면 그 말로 검색하고 필드에 채운다', (tester) async {
      await pumpSearch(tester, recent: ['아이유']);

      await tester.tap(inChips('아이유'));
      await tester.pumpAndSettle();

      expect(fieldText(tester), '아이유');
      expect(find.byType(ShowBannerCard), findsOneWidget);
      expect(find.text(MockHomeApi.iu.title), findsOneWidget);
    });

    testWidgets('추천 검색어 아바타를 누르면 그 이름으로 검색한다', (tester) async {
      await pumpSearch(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(RecommendedArtistRow),
          matching: find.text('리센느'),
        ),
      );
      await tester.pumpAndSettle();

      expect(fieldText(tester), '리센느');
      expect(find.text(MockHomeApi.remind.title), findsOneWidget);
      expect(store.keywords, ['리센느']);
    });

    testWidgets('인기 검색어 줄을 누르면 그 말로 검색한다', (tester) async {
      await pumpSearch(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(TrendingKeywordList),
          matching: find.text('RESCENE'),
        ),
      );
      await tester.pumpAndSettle();

      expect(fieldText(tester), 'RESCENE');
      expect(find.text(HomeStrings.searchEmpty('RESCENE')), findsOneWidget);
      expect(store.keywords, ['RESCENE']);
    });

    testWidgets('같은 검색어는 하나만 남고 맨 앞으로 온다', (tester) async {
      await pumpSearch(tester, recent: ['빅뱅', '아이유']);

      await submit(tester, '아이유');

      expect(store.keywords, ['아이유', '빅뱅']);
    });

    testWidgets('빈 검색어는 요청하지 않는다', (tester) async {
      await pumpSearch(tester);

      await submit(tester, '   ');

      expect(find.text(HomeStrings.recommendedSection), findsOneWidget);
      expect(find.byType(ShowBannerCard), findsNothing);
      expect(store.keywords, isEmpty);
    });

    testWidgets('지우기를 누르면 검색 전 화면으로 돌아온다', (tester) async {
      await pumpSearch(tester);
      await submit(tester, '아이유');
      expect(find.text(HomeStrings.recommendedSection), findsNothing);

      await tester.tap(find.byTooltip(HomeStrings.clearSearch));
      await tester.pumpAndSettle();

      expect(fieldText(tester), isEmpty);
      expect(find.text(HomeStrings.recommendedSection), findsOneWidget);
      expect(find.byType(ShowBannerCard), findsNothing);
    });
  });

  group('결과 카드', () {
    testWidgets('세 건까지만 보이고 더보기를 누르면 나머지가 펼쳐진다', (tester) async {
      await pumpSearch(tester, api: const _ManyResultsHomeApi());

      await submit(tester, '공연');
      expect(
        find.byType(ShowBannerCard),
        findsNWidgets(HomeMetrics.searchPreviewCount),
      );

      await tester.tap(find.text(HomeStrings.resultMore));
      await tester.pumpAndSettle();

      expect(
        find.byType(ShowBannerCard),
        findsNWidgets(_ManyResultsHomeApi.count),
      );
      expect(find.text(HomeStrings.resultMore), findsNothing);
    });

    testWidgets('세 건 이하면 더보기가 없다', (tester) async {
      await pumpSearch(tester);

      await submit(tester, '콘서트');

      expect(find.text(HomeStrings.resultMore), findsNothing);
    });

    testWidgets('카드를 누르면 상세가 열린다', (tester) async {
      await pumpSearch(tester);
      await submit(tester, '아이유');

      await tester.tap(find.byType(ShowBannerCard));
      await tester.pumpAndSettle();

      expect(find.byType(ShowDetailScreen), findsOneWidget);
    });

    testWidgets('카드의 하트를 누르면 찜 목록에 들어가고, 다시 누르면 빠진다', (tester) async {
      await pumpSearch(tester);
      await submit(tester, '아이유');

      // 첫 하트는 첫 결과 카드의 것이다(관련 아티스트 줄은 그 아래).
      await tester.tap(find.byTooltip(HomeStrings.favorite).first);
      await tester.pumpAndSettle();

      expect(favorites.favorites.shows, hasLength(1));
      // 서버에도 남는다. 기기를 바꿔도 찜이 따라오는 이유다.
      expect(favoriteApi.wishedIds, hasLength(1));
      expect(find.byTooltip(HomeStrings.unfavorite), findsOneWidget);

      await tester.tap(find.byTooltip(HomeStrings.unfavorite));
      await tester.pumpAndSettle();

      expect(favorites.favorites.shows, isEmpty);
      expect(favoriteApi.wishedIds, isEmpty);
      expect(find.byTooltip(HomeStrings.unfavorite), findsNothing);
    });

    testWidgets('로그아웃 상태에서 공연 하트를 누르면 로그인하라고 알린다', (tester) async {
      await pumpSearch(tester, loggedIn: false);
      await submit(tester, '아이유');

      await tester.tap(find.byTooltip(HomeStrings.favorite).first);
      await tester.pumpAndSettle();

      expect(find.text(FavoriteStrings.loginRequired), findsOneWidget);
      // 서버에 보내지 않았고 하트도 채워지지 않았다.
      expect(favoriteApi.wishedIds, isEmpty);
      expect(find.byTooltip(HomeStrings.unfavorite), findsNothing);
    });

    testWidgets('관련 아티스트의 하트를 누르면 찜 목록에 들어간다', (tester) async {
      await pumpSearch(tester);
      await submit(tester, '아이유');

      final heart = find
          .descendant(
            of: find.byType(RelatedArtistRow),
            matching: find.byTooltip(HomeStrings.favorite),
          )
          .first;
      await tester.ensureVisible(heart);
      await tester.tap(heart);
      await tester.pumpAndSettle();

      expect(favorites.favorites.artists.map((a) => a.name), ['아이유']);
      expect(
        find.descendant(
          of: find.byType(RelatedArtistRow),
          matching: find.byTooltip(HomeStrings.unfavorite),
        ),
        findsOneWidget,
      );
    });

    testWidgets('검색 결과가 오면 이미 찜한 아티스트의 사진이 최신으로 맞춰진다', (tester) async {
      await pumpSearch(tester, api: _PhotoArtistHomeApi());
      // 사진 없이 찜해 둔 아티스트. 사진 필드명이 어긋났던 동안 찜한 경우다.
      await favorites.toggleArtist(const FavoriteArtist(name: '아이유'));

      await submit(tester, '아이유');

      expect(favorites.favorites.artists, [
        const FavoriteArtist(
          name: '아이유',
          profileImageUrl: _PhotoArtistHomeApi.iuPhoto,
        ),
      ]);
    });
  });

  group('실패', () {
    testWidgets('공연 검색이 실패하면 문구와 다시 시도가 보이고, 다시 시도하면 재요청한다', (tester) async {
      final api = _FlakySearchHomeApi();
      await pumpSearch(tester, api: api);

      await submit(tester, '아이유');

      expect(find.text(_FlakySearchHomeApi.failureMessage), findsOneWidget);
      expect(find.text(AsyncBoundary.retryLabel), findsOneWidget);
      expect(find.byType(ShowBannerCard), findsNothing);
      // 관련 아티스트는 따로 받으므로 공연이 실패해도 보인다.
      expect(find.text(HomeStrings.relatedArtistSection), findsOneWidget);

      api.failing = false;
      await tester.tap(find.text(AsyncBoundary.retryLabel));
      await tester.pumpAndSettle();

      expect(find.text(_FlakySearchHomeApi.failureMessage), findsNothing);
      expect(find.byType(ShowBannerCard), findsOneWidget);
    });
  });

  group('최근 검색어 삭제', () {
    testWidgets('칩의 X 를 누르면 그 검색어만 지워진다', (tester) async {
      await pumpSearch(tester, recent: ['아이유', '빅뱅']);

      await tester.tap(find.byTooltip(HomeStrings.removeRecent('아이유')));
      await tester.pumpAndSettle();

      expect(inChips('아이유'), findsNothing);
      expect(inChips('빅뱅'), findsOneWidget);
      expect(store.keywords, ['빅뱅']);
    });

    testWidgets('전체 삭제를 누르면 섹션이 사라진다', (tester) async {
      await pumpSearch(tester, recent: ['아이유', '빅뱅']);

      await tester.tap(find.text(HomeStrings.clearRecent));
      await tester.pumpAndSettle();

      expect(find.byType(RecentSearchChips), findsNothing);
      expect(store.keywords, isEmpty);
    });
  });

  group('이동', () {
    testWidgets('하단 바의 홈을 누르면 셸로 돌아간다', (tester) async {
      await pumpSearch(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(AppBottomNavBar),
          matching: find.text(ShellStrings.homeTab),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ShowSearchScreen), findsNothing);
      expect(find.byType(MainShellScreen), findsOneWidget);
    });
  });
}

/// 결과가 미리보기 수보다 많은 서버. 더보기 흐름을 보는 데 쓴다.
class _ManyResultsHomeApi extends MockHomeApi {
  const _ManyResultsHomeApi() : super(latency: Duration.zero);

  static const count = 5;

  @override
  Future<List<ShowSummary>> search(String keyword) => Future.value([
    for (var i = 1; i <= count; i++)
      ShowSummary(
        id: 100 + i,
        title: '공연 $i',
        venueName: '공연장 $i',
        status: ShowSummary.onSaleStatus,
      ),
  ]);
}

/// 아티스트 검색이 사진 달린 아이유 한 명을 돌려준다. 목 데이터의 아티스트는
/// 모두 사진이 없어, 찜 스냅샷이 사진으로 갱신되는지 보려면 따로 필요하다.
class _PhotoArtistHomeApi implements HomeApi {
  static const iuPhoto = 'artist/iu.jpg';

  static const _mock = MockHomeApi(latency: Duration.zero);

  @override
  Future<List<ArtistSummary>> searchArtists(String keyword) async => const [
    ArtistSummary(name: '아이유', profileImageUrl: iuPhoto),
  ];

  @override
  Future<List<ShowSummary>> search(String keyword) => _mock.search(keyword);

  @override
  Future<List<ShowSummary>> fetchTicketOpenSoon() =>
      _mock.fetchTicketOpenSoon();

  @override
  Future<List<ShowSummary>> fetchPopular() => _mock.fetchPopular();

  @override
  Future<List<ArtistSummary>> fetchPopularArtists() =>
      _mock.fetchPopularArtists();

  @override
  Future<List<ArtistSummary>> fetchRecommendedArtists() =>
      _mock.fetchRecommendedArtists();

  @override
  Future<TrendingKeywords> fetchTrendingKeywords() =>
      _mock.fetchTrendingKeywords();
}

/// [failing] 인 동안 공연 검색만 서버 오류로 실패하고, 끄면 목 데이터로
/// 성공한다. 실패 -> 다시 시도 -> 성공 흐름을 한 테스트 안에서 본다.
class _FlakySearchHomeApi implements HomeApi {
  bool failing = true;

  static const failureMessage = '서버 응답이 늦어지고 있어요. 잠시 후 다시 시도해주세요.';

  static const _mock = MockHomeApi(latency: Duration.zero);

  /// 실패는 `Future.error` 가 아니라 잠깐 뒤에 던진다. 진짜 서버 실패도 요청이
  /// 나간 뒤 돌아오므로 그때는 결과 화면이 이미 그려져 [AsyncBoundary] 가
  /// 받는다. 즉시 실패한 Future 는 검색 제출 뒤 첫 프레임이 그려지기 전에
  /// "받는 곳 없는 오류" 로 잡혀 테스트만 깨진다. 지연은 `pumpAndSettle` 의
  /// 한 프레임(100ms)보다 길어야 한다.
  @override
  Future<List<ShowSummary>> search(String keyword) => failing
      ? Future.delayed(
          const Duration(milliseconds: 200),
          () => throw const ApiException(failureMessage),
        )
      : _mock.search(keyword);

  @override
  Future<List<ShowSummary>> fetchTicketOpenSoon() =>
      _mock.fetchTicketOpenSoon();

  @override
  Future<List<ShowSummary>> fetchPopular() => _mock.fetchPopular();

  @override
  Future<List<ArtistSummary>> fetchPopularArtists() =>
      _mock.fetchPopularArtists();

  @override
  Future<List<ArtistSummary>> fetchRecommendedArtists() =>
      _mock.fetchRecommendedArtists();

  @override
  Future<TrendingKeywords> fetchTrendingKeywords() =>
      _mock.fetchTrendingKeywords();

  @override
  Future<List<ArtistSummary>> searchArtists(String keyword) =>
      _mock.searchArtists(keyword);
}
