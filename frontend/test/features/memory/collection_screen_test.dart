import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/auth/data/mock_auth_api.dart';
import 'package:timo/features/auth/data/token_storage.dart';
import 'package:timo/features/auth/state/auth_session.dart';
import 'package:timo/features/auth/state/auth_session_scope.dart';
import 'package:timo/features/memory/constants.dart';
import 'package:timo/features/memory/data/memory_concert_api.dart';
import 'package:timo/features/memory/data/ticket_store.dart';
import 'package:timo/features/memory/models/concert_kit.dart';
import 'package:timo/features/memory/models/memory_concert.dart';
import 'package:timo/features/memory/models/memory_ticket.dart';
import 'package:timo/features/memory/screens/collection_screen.dart';
import 'package:timo/features/memory/theme/memory_theme.dart';

import 'memory_scopes.dart';

/// 정해진 카탈로그만 돌려주는 서버.
class _CatalogApi implements MemoryConcertApi {
  _CatalogApi(this.concerts);
  final List<MemoryConcert> concerts;

  @override
  Future<List<MemoryConcert>> getConcerts() async => concerts;

  @override
  Future<ConcertKit> getKit(String concertId) async => ConcertKit.demo;
}

MemoryTicket _ticket(
  String ticketId, {
  bool confirmed = false,
  String? goodsId,
}) => MemoryTicket(
  ticketId: ticketId,
  concertId: 'c',
  backgroundPath: '/none/$ticketId.png',
  personCompositePath: null,
  effectType: '효과 없음',
  videoId: 'v',
  videoUrl: '',
  details: const {'공연명': '공연'},
  depthLayers: const [],
  demoDepth: true,
  confirmed: confirmed,
  goodsId: goodsId,
);

const _concert = MemoryConcert(
  ticketId: '1024',
  id: '3',
  title: '빛으로 남은 밤',
  artist: 'TIMO STAGE',
  date: '2026.09.26',
  venue: '서울 메모리 홀',
  poster: '',
  videoUrl: '',
);

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required TicketStore store,
    required List<MemoryConcert> concerts,
  }) async {
    final session = AuthSession(storage: InMemoryTokenStorage());
    await session.signIn(MockAuthApi.tokens);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      AuthSessionScope(
        session: session,
        child: MaterialApp(
          theme: timoTheme(),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: withMemoryScopes(
              const CollectionScreen(),
              store: store,
              concertApi: _CatalogApi(concerts),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('입장한 공연이 없으면 "모두 보기" 가 이유를 말한다', (tester) async {
    await pump(tester, store: InMemoryTicketStore(), concerts: const []);

    await tester.tap(find.text(CollectionText.filterAll));
    await tester.pumpAndSettle();

    expect(find.text(CollectionText.catalogEmptyTitle), findsOneWidget);
  });

  testWidgets('서버가 모르는 소장품은 지우고, 카탈로그의 것과 서버에 있는 것은 남긴다', (tester) async {
    final store = InMemoryTicketStore();
    // 목 카탈로그 시절에 만든 것 — 서버가 모르는 티켓 번호다. 임시본이든,
    // 확정 개념이 생기기 전에 저장돼 확정본으로 읽히는 것이든 마찬가지다.
    await store.save(_ticket('ticket-4096'));
    await store.save(_ticket('ticket-2048', confirmed: true));
    // 카탈로그에 있는 티켓의 임시본은 아직 확정할 수 있다.
    await store.save(_ticket('1024'));
    // 서버 번호가 있으면 서버에 있는 것이다. 카탈로그에서 빠졌어도 지우지 않는다.
    await store.save(_ticket('7', confirmed: true, goodsId: '77'));

    await pump(tester, store: store, concerts: const [_concert]);
    // 정리는 카탈로그를 받은 뒤 비동기로 돈다 — 삭제가 다 끝날 때까지 프레임을
    // 넘긴다. 프레임 하나에 끝날 것이라고 보면 CI 처럼 느린 자리에서 흔들린다.
    for (var i = 0; i < 20 && store.readAll().length > 2; i++) {
      await tester.pump();
    }

    expect(
      store.readAll().map((t) => t.ticketId),
      unorderedEquals(['1024', '7']),
    );
  });
}
