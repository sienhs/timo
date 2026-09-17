import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/app.dart';
import 'package:timo/features/favorite/constants.dart';
import 'package:timo/features/favorite/data/favorite_store.dart';
import 'package:timo/features/favorite/models/favorite_artist.dart';
import 'package:timo/features/favorite/models/favorite_show.dart';
import 'package:timo/features/favorite/models/favorites.dart';
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
  final seeded = Favorites(
    shows: [bigbang, iu, rescene],
    artists: const [iuArtist, bigbangArtist],
  );

  late InMemoryFavoriteStore store;
  late InMemoryRecentSearchStore recent;

  /// 360 x 800 dp
  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// 홈 셸의 빠른 메뉴에서 '찜' 을 눌러 찜리스트까지 간다.
  Future<void> pumpFavorites(
    WidgetTester tester, {
    Favorites favorites = const Favorites(),
  }) async {
    usePhoneSize(tester);
    store = InMemoryFavoriteStore(favorites);
    addTearDown(store.dispose);
    recent = InMemoryRecentSearchStore();
    await tester.pumpWidget(
      App(
        // 로딩 화면을 건너뛰고 홈에서 시작한다.
        initialRoute: AppRoutes.home,
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
      await pumpFavorites(tester, favorites: Favorites(shows: [bigbang]));

      await tester.tap(find.text('${FavoriteStrings.artistTab} 0'));
      await tester.pumpAndSettle();

      expect(find.text(FavoriteStrings.noArtists), findsOneWidget);
      expect(find.byType(FavoriteShowCard), findsNothing);
    });
  });

  group('공연 탭', () {
    testWidgets('찜한 공연이 최근 찜한 순으로 보이고 탭에 개수가 붙는다', (tester) async {
      await pumpFavorites(tester, favorites: seeded);

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
      await pumpFavorites(tester, favorites: seeded);

      await tester.tap(find.text('${FavoriteStrings.filterClosed} 1'));
      await tester.pumpAndSettle();

      expect(find.text(FavoriteStrings.showCount(1)), findsOneWidget);
      expect(cardTitles(tester), [rescene.title]);

      await tester.tap(find.text('${FavoriteStrings.filterOnSale} 2'));
      await tester.pumpAndSettle();

      expect(cardTitles(tester), [bigbang.title, iu.title]);
    });

    testWidgets('검색어를 치면 제목에 그 말이 든 공연만 남고, 없으면 검색어를 되비춘다', (tester) async {
      await pumpFavorites(tester, favorites: seeded);

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
      await pumpFavorites(tester, favorites: seeded);

      await tester.tap(find.text(FavoriteStrings.sortRecent));
      await tester.pumpAndSettle();
      await tester.tap(find.text(FavoriteStrings.sortUpcoming).last);
      await tester.pumpAndSettle();

      expect(cardTitles(tester), [rescene.title, iu.title, bigbang.title]);
    });

    testWidgets('하트를 누르면 빠지고, 되돌리기로 살린다', (tester) async {
      await pumpFavorites(tester, favorites: seeded);

      await tester.tap(find.byTooltip(FavoriteStrings.unfavorite).first);
      await tester.pumpAndSettle();

      expect(store.favorites.hasShow(bigbang.id), isFalse);
      expect(cardTitles(tester), [iu.title, rescene.title]);
      expect(find.text('${FavoriteStrings.showTab} 2'), findsOneWidget);
      expect(find.text(FavoriteStrings.removed), findsOneWidget);

      await tester.tap(find.text(FavoriteStrings.undo));
      await tester.pumpAndSettle();

      expect(store.favorites.hasShow(bigbang.id), isTrue);
      expect(find.byType(FavoriteShowCard), findsNWidgets(3));
    });

    testWidgets('카드를 누르면 공연 상세가 열린다', (tester) async {
      await pumpFavorites(tester, favorites: seeded);

      await tester.tap(find.text(iu.title));
      await tester.pumpAndSettle();

      expect(find.byType(ShowDetailScreen), findsOneWidget);
    });
  });

  group('아티스트 탭', () {
    testWidgets('찜한 아티스트가 보이고, 검색어로 좁힐 수 있다', (tester) async {
      await pumpFavorites(tester, favorites: seeded);
      await openArtistTab(tester);

      expect(find.text(FavoriteStrings.artistCount(2)), findsOneWidget);
      expect(tileNames(tester), [iuArtist.name, bigbangArtist.name]);
      expect(find.byType(FavoriteShowCard), findsNothing);

      await tester.enterText(find.byType(TextField), 'big');
      await tester.pumpAndSettle();
      expect(tileNames(tester), [bigbangArtist.name]);
    });

    testWidgets('탭을 바꾸면 검색어는 비워진다', (tester) async {
      await pumpFavorites(tester, favorites: seeded);
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
      await pumpFavorites(tester, favorites: seeded);
      await openArtistTab(tester);

      await tester.tap(find.text(FavoriteStrings.sortRecent));
      await tester.pumpAndSettle();
      await tester.tap(find.text(FavoriteStrings.sortName).last);
      await tester.pumpAndSettle();

      expect(tileNames(tester), [bigbangArtist.name, iuArtist.name]);
    });

    testWidgets('하트를 누르면 빠진다', (tester) async {
      await pumpFavorites(tester, favorites: seeded);
      await openArtistTab(tester);

      await tester.tap(find.byTooltip(FavoriteStrings.unfavorite).first);
      await tester.pumpAndSettle();

      expect(store.favorites.hasArtist(iuArtist.name), isFalse);
      expect(tileNames(tester), [bigbangArtist.name]);
      expect(find.text('${FavoriteStrings.artistTab} 1'), findsOneWidget);
    });

    testWidgets('줄을 누르면 그 이름으로 검색된 화면이 열리고 최근 검색어에 남는다', (tester) async {
      await pumpFavorites(tester, favorites: seeded);
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
    await pumpFavorites(tester, favorites: Favorites(shows: [bigbang]));

    await store.toggleShow(iu);
    await tester.pumpAndSettle();

    expect(cardTitles(tester), [iu.title, bigbang.title]);
    expect(find.text('${FavoriteStrings.showTab} 2'), findsOneWidget);
  });
}
