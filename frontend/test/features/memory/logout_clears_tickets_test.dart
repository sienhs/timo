import 'package:flutter_test/flutter_test.dart';
import 'package:timo/app.dart';
import 'package:timo/features/auth/data/token_storage.dart';
import 'package:timo/features/auth/models/auth_tokens.dart';
import 'package:timo/features/auth/state/auth_session.dart';
import 'package:timo/features/favorite/data/favorite_artist_store.dart';
import 'package:timo/features/favorite/data/favorite_store.dart';
import 'package:timo/features/favorite/data/mock_favorite_api.dart';
import 'package:timo/features/home/data/mock_home_api.dart';
import 'package:timo/features/home/data/recent_search_store.dart';
import 'package:timo/features/memory/data/ticket_store.dart';
import 'package:timo/features/memory/models/memory_ticket.dart';
import 'package:timo/features/show/data/mock_show_api.dart';
import 'package:timo/routes/app_routes.dart';

/// 소장품은 계정의 것인데 저장소는 기기에 하나다. 그래서 App 은 로그아웃을
/// 보면 저장소를 비워, 다음에 로그인한 사람이 앞사람 소장품을 보지 않게 한다.
void main() {
  const tokens = AuthTokens(
    memberId: 1,
    accessToken: 'test-access-token',
    refreshToken: 'test-refresh-token',
    accessTokenExpiresIn: Duration(minutes: 30),
  );

  const ticket = MemoryTicket(
    ticketId: '1024',
    concertId: 'c',
    backgroundPath: '/none/1024.png',
    personCompositePath: null,
    effectType: '효과 없음',
    videoId: 'v',
    videoUrl: '',
    details: {'공연명': '공연'},
    depthLayers: [],
    demoDepth: true,
  );

  Future<({AuthSession session, TicketStore store})> pumpApp(
    WidgetTester tester, {
    required bool loggedIn,
  }) async {
    final session = AuthSession(storage: InMemoryTokenStorage());
    if (loggedIn) await session.signIn(tokens);
    addTearDown(session.dispose);
    final store = InMemoryTicketStore();
    await store.save(ticket);
    final favorites = FavoriteStore(
      api: MockFavoriteApi(),
      artistStore: InMemoryFavoriteArtistStore(),
    );
    addTearDown(favorites.dispose);
    await tester.pumpWidget(
      App(
        initialRoute: AppRoutes.home,
        session: session,
        ticketStore: store,
        favoriteStore: favorites,
        recentSearchStore: InMemoryRecentSearchStore(),
        homeApi: MockHomeApi(latency: Duration.zero),
        showApi: const MockShowApi(latency: Duration.zero),
      ),
    );
    await tester.pumpAndSettle();
    return (session: session, store: store);
  }

  testWidgets('로그아웃하면 기기의 소장품이 전부 비워진다', (tester) async {
    final (:session, :store) = await pumpApp(tester, loggedIn: true);
    expect(store.readAll(), hasLength(1));

    await session.signOut();
    await tester.pumpAndSettle();

    expect(store.readAll(), isEmpty);
  });

  testWidgets('로그인한 채로는 토큰이 갱신되어도 소장품이 남는다', (tester) async {
    final (:session, :store) = await pumpApp(tester, loggedIn: true);

    // 세션은 토큰을 새로 받을 때도 알린다. 로그인 여부가 안 바뀌면 비우지 않는다.
    await session.signIn(tokens);
    await tester.pumpAndSettle();

    expect(store.readAll(), hasLength(1));
  });

  testWidgets('로그아웃 상태로 켜져도 저장소는 건드리지 않는다', (tester) async {
    // 이미 로그아웃된 채 켜진 것은 계정이 바뀐 일이 아니다. 로그아웃 순간에만
    // 비운다.
    final (:store, session: _) = await pumpApp(tester, loggedIn: false);
    expect(store.readAll(), hasLength(1));
  });
}
