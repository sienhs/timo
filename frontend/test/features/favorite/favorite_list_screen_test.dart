import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/app.dart';
import 'package:timo/core/widgets/async_boundary.dart';
import 'package:timo/features/auth/models/auth_tokens.dart';
import 'package:timo/features/auth/data/token_storage.dart';
import 'package:timo/features/auth/state/auth_session.dart';
import 'package:timo/features/favorite/constants.dart';
import 'package:timo/features/favorite/data/favorite_artist_store.dart';
import 'package:timo/features/favorite/data/favorite_store.dart';
import 'package:timo/features/favorite/data/mock_favorite_api.dart';
import 'package:timo/features/favorite/models/favorite_artist.dart';
import 'package:timo/features/favorite/models/favorite_show.dart';
import 'package:timo/features/favorite/screens/favorite_list_screen.dart';
import 'package:timo/features/favorite/widgets/favorite_artist_tile.dart';
import 'package:timo/features/favorite/widgets/favorite_show_card.dart';
import 'package:timo/features/home/data/mock_home_api.dart';
import 'package:timo/features/home/data/recent_search_store.dart';
import 'package:timo/features/home/screens/show_search_screen.dart';
import 'package:timo/features/shell/widgets/quick_menu_button.dart';
import 'package:timo/features/show/data/mock_show_api.dart';
import 'package:timo/features/show/screens/show_detail_screen.dart';
import 'package:timo/routes/app_routes.dart';

/// 찜리스트 화면. 빠른 메뉴에서 들어가 '무엇이 보이는가' 와 '누르면 어디로
/// 가는가' 만 본다. 픽셀 값은 시안이 바뀌면 같이 바뀌므로 테스트로 굳히지 않는다.
void main() {
  const bigbang = FavoriteShow(
    id: 1,
    title: '2026 BIGBANG',
    venueName: '올림픽공원 체조경기장',
    isOnSale: true,
  );
  final iu = FavoriteShow(
    id: 2,
    title: '2026 아이유 콘서트',
    venueName: '고척스카이돔',
    isOnSale: true,
    startAt: DateTime(2026, 11, 4, 18),
  );
  final rescene = FavoriteShow(
    id: 3,
    title: '2026 RE:MIND: 리센느',
    venueName: '올림픽공원 체조경기장',
    isOnSale: false,
    startAt: DateTime(2026, 5, 20, 19),
  );
  const iuArtist = FavoriteArtist(name: '아이유');
  const bigbangArtist = FavoriteArtist(name: 'BIGBANG');

  /// 최근 찜한 순: 빅뱅 → 아이유 → 리센느.
  final seededShows = [bigbang, iu, rescene];
  const seededArtists = [iuArtist, bigbangArtist];

  /// 로그인 상태를 만드는 토큰. 공연 찜은 서버에 있어 로그인해야 보인다.
  const tokens = AuthTokens(
    memberId: 1,
    accessToken: 'test-access-token',
    refreshToken: 'test-refresh-token',
    accessTokenExpiresIn: Duration(minutes: 30),
  );

  late MockFavoriteApi api;
  late FavoriteStore store;
  late InMemoryRecentSearchStore recent;

  /// 360 x 800 dp
  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// 홈 셸의 빠른 메뉴에서 '찜' 을 눌러 찜리스트까지 간다. [shows] 는 서버가
  /// 들고 있는 찜 공연, [artists] 는 기기에 남아 있던 아티스트다. [loggedIn] 을
  /// 끄면 로그아웃 상태로 연다.
  Future<void> pumpFavorites(
    WidgetTester tester, {
    List<FavoriteShow> shows = const [],
    List<FavoriteArtist> artists = const [],
    bool loggedIn = true,
    bool serverFailing = false,
  }) async {
    usePhoneSize(tester);
    api = MockFavoriteApi(shows: shows, failing: serverFailing);
    store = FavoriteStore(
      api: api,
      artistStore: InMemoryFavoriteArtistStore(artists),
    );
    addTearDown(store.dispose);
    final session = AuthSession(storage: InMemoryTokenStorage());
    if (loggedIn) await session.signIn(tokens);
    addTearDown(session.dispose);
    recent = InMemoryRecentSearchStore();
    await tester.pumpWidget(
      App(
        // 로딩 화면을 건너뛰고 홈에서 시작한다.
        initialRoute: AppRoutes.home,
        session: session,
        favoriteStore: store,
        recentSearchStore: recent,
        homeApi: MockHomeApi(latency: Duration.zero),
        // 카드를 누르면 공연 상세가 열린다. 목을 안 꽂으면 진짜 서버로 간다.
        showApi: const MockShowApi(latency: Duration.zero),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(QuickMenuButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('찜'));
    await tester.pumpAndSettle();
    expect(find.byType(FavoriteListScreen), findsOneWidget);
  }

  Iterable<String> cardTitles(WidgetTester tester) => tester
      .widgetList<FavoriteShowCard>(find.byType(FavoriteShowCard))
      .map((card) => card.show.title);

  Iterable<String> tileNames(WidgetTester tester) => tester
      .widgetList<FavoriteArtistTile>(find.byType(FavoriteArtistTile))
      .map((tile) => tile.artist.name);

  Future<void> openArtistTab(WidgetTester tester) async {
    await tester.tap(find.text('${FavoriteStrings.artistTab} 2'));
    await tester.pumpAndSettle();
  }

  group('빈 화면', () {
    testWidgets('찜한 것이 없으면 안내와 둘러보기 버튼이 보이고, 누르면 검색이 열린다', (tester) async {
      await pumpFavorites(tester);

      expect(find.text('${FavoriteStrings.showTab} 0'), findsOneWidget);
      expect(find.text(FavoriteStrings.noShows), findsOneWidget);
      expect(find.text(FavoriteStrings.showCount(0)), findsNothing);

      await tester.tap(find.text(FavoriteStrings.browseShows));
      await tester.pumpAndSettle();

      expect(find.byType(ShowSearchScreen), findsOneWidget);
    });

    testWidgets('아티스트 탭도 따로 비어 있다고 알린다', (tester) async {
      await pumpFavorites(tester, shows: [bigbang]);

      await tester.tap(find.text('${FavoriteStrings.artistTab} 0'));
      await tester.pumpAndSettle();

      expect(find.text(FavoriteStrings.noArtists), findsOneWidget);
      expect(find.byType(FavoriteShowCard), findsNothing);
    });
  });

  group('공연 탭', () {
    testWidgets('찜한 공연이 최근 찜한 순으로 보이고 탭에 개수가 붙는다', (tester) async {
      await pumpFavorites(tester, shows: seededShows, artists: seededArtists);

      expect(find.text('${FavoriteStrings.showTab} 3'), findsOneWidget);
      expect(find.text('${FavoriteStrings.artistTab} 2'), findsOneWidget);
      expect(find.text(FavoriteStrings.showCount(3)), findsOneWidget);
      expect(cardTitles(tester), [bigbang.title, iu.title, rescene.title]);
      // 끝난 공연에만 뱃지가 붙는다.
      expect(find.text(FavoriteStrings.closedBadge), findsOneWidget);
      expect(find.text('2026.11.04 18:00'), findsOneWidget);
      expect(find.text(FavoriteStrings.dateUndecided), findsOneWidget);
    });

    testWidgets('판매 종료 칩을 누르면 끝난 공연만 남는다', (tester) async {
      await pumpFavorites(tester, shows: seededShows, artists: seededArtists);

      await tester.tap(find.text('${FavoriteStrings.filterClosed} 1'));
      await tester.pumpAndSettle();

      expect(find.text(FavoriteStrings.showCount(1)), findsOneWidget);
      expect(cardTitles(tester), [rescene.title]);

      await tester.tap(find.text('${FavoriteStrings.filterOnSale} 2'));
      await tester.pumpAndSettle();

      expect(cardTitles(tester), [bigbang.title, iu.title]);
    });

    testWidgets('검색어를 치면 제목에 그 말이 든 공연만 남고, 없으면 검색어를 되비춘다', (tester) async {
      await pumpFavorites(tester, shows: seededShows, artists: seededArtists);

      await tester.enterText(find.byType(TextField), '아이유');
      await tester.pumpAndSettle();
      expect(cardTitles(tester), [iu.title]);

      await tester.enterText(find.byType(TextField), '블랙핑크');
      await tester.pumpAndSettle();
      expect(find.byType(FavoriteShowCard), findsNothing);
      expect(find.text(FavoriteStrings.noShowsFor('블랙핑크')), findsOneWidget);

      await tester.tap(find.byTooltip(FavoriteStrings.clearSearch));
      await tester.pumpAndSettle();
      expect(find.byType(FavoriteShowCard), findsNWidgets(3));
    });

    testWidgets('공연 임박 순으로 바꾸면 시작이 빠른 것부터, 일정 미정은 맨 뒤다', (tester) async {
      await pumpFavorites(tester, shows: seededShows, artists: seededArtists);

      await tester.tap(find.text(FavoriteStrings.sortRecent));
      await tester.pumpAndSettle();
      await tester.tap(find.text(FavoriteStrings.sortUpcoming).last);
      await tester.pumpAndSettle();

      expect(cardTitles(tester), [rescene.title, iu.title, bigbang.title]);
    });

    testWidgets('하트를 누르면 빠지고, 되돌리기로 살린다', (tester) async {
      await pumpFavorites(tester, shows: seededShows, artists: seededArtists);

      await tester.tap(find.byTooltip(FavoriteStrings.unfavorite).first);
      await tester.pumpAndSettle();

      expect(store.favorites.hasShow(bigbang.id), isFalse);
      // 서버에서도 빠졌다. 화면만 바뀌면 다음에 열 때 되살아난다.
      expect(api.wishedIds, isNot(contains(bigbang.id)));
      expect(cardTitles(tester), [iu.title, rescene.title]);
      expect(find.text('${FavoriteStrings.showTab} 2'), findsOneWidget);
      expect(find.text(FavoriteStrings.removed), findsOneWidget);

      await tester.tap(find.text(FavoriteStrings.undo));
      await tester.pumpAndSettle();

      expect(store.favorites.hasShow(bigbang.id), isTrue);
      expect(api.wishedIds, contains(bigbang.id));
      expect(find.byType(FavoriteShowCard), findsNWidgets(3));
    });

    testWidgets('되돌리기 안내는 누르지 않아도 2초 뒤 내려간다', (tester) async {
      await pumpFavorites(tester, shows: seededShows, artists: seededArtists);

      await tester.tap(find.byTooltip(FavoriteStrings.unfavorite).first);
      await tester.pumpAndSettle();
      expect(find.text(FavoriteStrings.removed), findsOneWidget);

      // 버튼이 달린 토스트는 Flutter 기본값이면 누를 때까지 남는다.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text(FavoriteStrings.removed), findsNothing);
      // 되돌리지 않았으니 빠진 채다.
      expect(store.favorites.hasShow(bigbang.id), isFalse);
    });

    testWidgets('카드를 누르면 공연 상세가 열린다', (tester) async {
      await pumpFavorites(tester, shows: seededShows, artists: seededArtists);

      await tester.tap(find.text(iu.title));
      await tester.pumpAndSettle();

      expect(find.byType(ShowDetailScreen), findsOneWidget);
    });
  });

  group('로그인·불러오기', () {
    testWidgets('로그아웃 상태면 공연 탭에 로그인 안내가 뜬다', (tester) async {
      // 서버에 찜이 있어도 물어볼 수 없다. 모든 찜 주소가 로그인을 요구한다.
      await pumpFavorites(tester, shows: [bigbang], loggedIn: false);

      expect(find.text(FavoriteStrings.guestShows), findsOneWidget);
      expect(find.text(FavoriteStrings.login), findsOneWidget);
      expect(find.byType(FavoriteShowCard), findsNothing);
    });

    testWidgets('로그아웃 상태면 아티스트 탭에도 로그인 안내가 뜬다', (tester) async {
      // 아티스트 찜은 기기에 있어 그릴 수는 있지만, 공연 탭과 같이 로그인해야
      // 보인다. 탭 카운트도 기기에 둘이 있어도 0 이다.
      await pumpFavorites(tester, artists: seededArtists, loggedIn: false);

      await tester.tap(find.text('${FavoriteStrings.artistTab} 0'));
      await tester.pumpAndSettle();

      expect(find.text(FavoriteStrings.guestArtists), findsOneWidget);
      expect(find.text(FavoriteStrings.login), findsOneWidget);
      expect(find.byType(FavoriteArtistTile), findsNothing);
    });

    testWidgets('목록을 못 받으면 다시 시도가 뜨고, 눌러 되살린다', (tester) async {
      await pumpFavorites(tester, shows: [bigbang], serverFailing: true);

      expect(find.text(AsyncBoundary.retryLabel), findsOneWidget);
      expect(find.byType(FavoriteShowCard), findsNothing);

      api.failing = false;
      await tester.tap(find.text(AsyncBoundary.retryLabel));
      await tester.pumpAndSettle();

      expect(cardTitles(tester), [bigbang.title]);
    });
  });

  group('아티스트 탭', () {
    testWidgets('찜한 아티스트가 보이고, 검색어로 좁힐 수 있다', (tester) async {
      await pumpFavorites(tester, shows: seededShows, artists: seededArtists);
      await openArtistTab(tester);

      expect(find.text(FavoriteStrings.artistCount(2)), findsOneWidget);
      expect(tileNames(tester), [iuArtist.name, bigbangArtist.name]);
      expect(find.byType(FavoriteShowCard), findsNothing);

      await tester.enterText(find.byType(TextField), 'big');
      await tester.pumpAndSettle();
      expect(tileNames(tester), [bigbangArtist.name]);
    });

    testWidgets('탭을 바꾸면 검색어는 비워진다', (tester) async {
      await pumpFavorites(tester, shows: seededShows, artists: seededArtists);
      await tester.enterText(find.byType(TextField), '아이유');
      await tester.pumpAndSettle();

      await openArtistTab(tester);

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(tileNames(tester), hasLength(2));
    });

    testWidgets('이름 순으로 바꿀 수 있다', (tester) async {
      await pumpFavorites(tester, shows: seededShows, artists: seededArtists);
      await openArtistTab(tester);

      await tester.tap(find.text(FavoriteStrings.sortRecent));
      await tester.pumpAndSettle();
      await tester.tap(find.text(FavoriteStrings.sortName).last);
      await tester.pumpAndSettle();

      expect(tileNames(tester), [bigbangArtist.name, iuArtist.name]);
    });

    testWidgets('하트를 누르면 빠진다', (tester) async {
      await pumpFavorites(tester, shows: seededShows, artists: seededArtists);
      await openArtistTab(tester);

      await tester.tap(find.byTooltip(FavoriteStrings.unfavorite).first);
      await tester.pumpAndSettle();

      expect(store.favorites.hasArtist(iuArtist.name), isFalse);
      expect(tileNames(tester), [bigbangArtist.name]);
      expect(find.text('${FavoriteStrings.artistTab} 1'), findsOneWidget);
    });

    testWidgets('줄을 누르면 그 이름으로 검색된 화면이 열리고 최근 검색어에 남는다', (tester) async {
      await pumpFavorites(tester, shows: seededShows, artists: seededArtists);
      await openArtistTab(tester);

      await tester.tap(find.text(bigbangArtist.name));
      await tester.pumpAndSettle();

      expect(find.byType(ShowSearchScreen), findsOneWidget);
      final field = find.descendant(
        of: find.byType(ShowSearchScreen),
        matching: find.byType(TextField),
      );
      expect(
        tester.widget<TextField>(field).controller!.text,
        bigbangArtist.name,
      );
      expect(recent.keywords, [bigbangArtist.name]);
    });
  });

  testWidgets('다른 곳에서 찜 목록이 바뀌면 화면도 따라 바뀐다', (tester) async {
    await pumpFavorites(tester, shows: [bigbang]);

    // 하트는 바로 반영되고 서버로는 조금 뒤에 나간다. pumpAndSettle 은 대기
    // 중인 타이머를 건드리지 못하므로 그 시각까지 직접 당겨 준다.
    final sent = store.toggleShow(iu);
    await tester.pump(FavoriteLimits.toggleDebounce);
    await tester.pumpAndSettle();

    expect(cardTitles(tester), [iu.title, bigbang.title]);
    expect(find.text('${FavoriteStrings.showTab} 2'), findsOneWidget);
    await sent;
  });

  /// 검색 칸을 누르면 키보드가 올라온다. 이때 화면을 줄이면 하단 바 위의 원형
  /// 버튼이 키보드를 피해 본문 한가운데로 따라 올라와, 그 자리에 있던 버튼
  /// 위에 겹친다. 줄이지 않는 대신 목록 아래 여백으로 키보드를 피한다.
  testWidgets('키보드가 올라와도 화면을 줄이지 않아 원형 버튼이 따라 오르지 않는다', (tester) async {
    await pumpFavorites(tester, shows: seededShows);

    final scaffold = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(FavoriteListScreen),
        matching: find.byType(Scaffold),
      ),
    );
    expect(scaffold.resizeToAvoidBottomInset, isFalse);
  });
}
