import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/widgets/timo_mascot.dart';
import 'package:timo/features/memory/theme/memory_theme.dart';
import 'package:timo/features/memory/constants.dart';
import 'package:timo/features/memory/models/collection_slot.dart';
import 'package:timo/features/memory/models/memory_ticket.dart';
import 'package:timo/features/memory/widgets/collection/catalog_grid.dart';
import 'package:timo/features/memory/widgets/collection/ticket_orgel.dart';
import 'package:timo/features/memory/widgets/collection/collection_view.dart';
import 'package:timo/features/memory/widgets/collection/ticket_thumbnail.dart';

void main() {
  const slots = [
    CollectionSlot(
      ticketId: 't1',
      concertId: 'c1',
      title: '빛으로 남은 밤',
      artist: 'TIMO STAGE',
      date: '2026.09.26',
      poster: 'assets/demo/stage_blue.png',
    ),
    CollectionSlot(
      ticketId: 't2',
      concertId: 'c2',
      title: '우리의 여름, 앙코르',
      artist: 'TIMO BAND',
      date: '2026.10.03',
      poster: 'assets/demo/stage_gold.png',
    ),
  ];

  testWidgets('starts on "내가 만든 소장품 보기", and the catalogue shows a '
      'placeholder per ticket that starts the creator for that ticket',
      (tester) async {
    CollectionSlot? started;
    await tester.pumpWidget(
      MaterialApp(
        theme: timoTheme(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: CollectionView(
            slots: slots,
            tickets: const [],
            onCreate: () {},
            onCreateFor: (slot) => started = slot,
            onOpen: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(CollectionText.title), findsOneWidget);

    // 첫 진입은 "내가 만든 소장품 보기". 만든 소장품이 없으면 빈 무대가 보인다.
    // 빈 자리는 마스코트가 지킨다. 티켓 자리표시를 쓰면 격자의 아직 만들지
    // 않은 칸과 구분이 안 된다.
    expect(find.text(CollectionText.emptyTitle), findsOneWidget);
    expect(find.byType(TimoMascot), findsOneWidget);
    expect(find.byType(TicketPlaceholder), findsNothing);

    // "모두 보기"로 바꾸면 티켓마다 자리표시가 하나씩 나온다.
    await tester.tap(find.text(CollectionText.filterAll));
    await tester.pumpAndSettle();
    expect(find.text(CollectionText.emptyTitle), findsNothing);
    expect(find.byType(TicketPlaceholder), findsNWidgets(2));

    await tester.tap(find.byType(TicketPlaceholder).last);
    await tester.pump();
    expect(started?.ticketId, 't2');
    expect(tester.takeException(), isNull);
  });

  const ticket = MemoryTicket(
    ticketId: 't1',
    concertId: 'c1',
    backgroundPath: '/none/t1.png',
    personCompositePath: null,
    effectType: '효과 없음',
    videoId: 'v',
    videoUrl: '',
    details: {'공연명': '빛으로 남은 밤'},
    depthLayers: [],
    demoDepth: true,
  );

  testWidgets('필터를 오가도 보던 쪽을 다시 만들지 않는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: timoTheme(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: CollectionView(
            slots: slots,
            tickets: const [ticket],
            onCreate: () {},
            onCreateFor: (_) {},
            onOpen: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final orgel = tester.state(find.byType(TicketOrgel));

    // "모두 보기" 로 가면 오르골은 화면에서 빠지지만 트리에는 남는다 —
    // 돌려놓은 각도를 들고 있는 것이 저 State 다.
    await tester.tap(find.text(CollectionText.filterAll));
    await tester.pumpAndSettle();
    expect(find.byType(CatalogGrid), findsOneWidget);
    expect(find.byType(TicketOrgel), findsNothing);
    expect(find.byType(TicketOrgel, skipOffstage: false), findsOneWidget);

    // 돌아오면 그 State 그대로다. 격자도 버리지 않아 스크롤 위치가 남는다.
    await tester.tap(find.text(CollectionText.filterMine));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(TicketOrgel)), same(orgel));
    expect(find.byType(CatalogGrid), findsNothing);
    expect(find.byType(CatalogGrid, skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
