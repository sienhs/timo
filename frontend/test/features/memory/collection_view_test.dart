import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/widgets/timo_mascot.dart';
import 'package:timo/features/memory/theme/memory_theme.dart';
import 'package:timo/features/memory/constants.dart';
import 'package:timo/features/memory/models/collection_slot.dart';
import 'package:timo/features/memory/widgets/collection/collection_view.dart';
import 'package:timo/features/memory/widgets/collection/ticket_thumbnail.dart';

void main() {
  const slots = [
    CollectionSlot(
      concertId: 'c1',
      title: '빛으로 남은 밤',
      artist: 'TIMO STAGE',
      date: '2026.09.26',
      poster: 'assets/demo/stage_blue.png',
    ),
    CollectionSlot(
      concertId: 'c2',
      title: '우리의 여름, 앙코르',
      artist: 'TIMO BAND',
      date: '2026.10.03',
      poster: 'assets/demo/stage_gold.png',
    ),
  ];

  testWidgets('starts on "내가 가진 티켓만 보기", and the catalogue shows a '
      'placeholder per concert that starts the creator for that concert',
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
            onDelete: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(CollectionText.title), findsOneWidget);

    // 첫 진입은 "내가 가진 티켓만 보기". 가진 티켓이 없으면 빈 무대가 보인다.
    // 빈 자리는 마스코트가 지킨다. 회색 티켓 자리표시를 쓰면 격자의
    // '아직 없는 소장품' 칸과 구분이 안 된다.
    expect(find.text(CollectionText.emptyTitle), findsOneWidget);
    expect(find.byType(TimoMascot), findsOneWidget);
    expect(find.byType(TicketPlaceholder), findsNothing);

    // "모두 보기"로 바꾸면 공연마다 자리표시가 하나씩 나온다.
    await tester.tap(find.text(CollectionText.filterAll));
    await tester.pumpAndSettle();
    expect(find.text(CollectionText.emptyTitle), findsNothing);
    expect(find.byType(TicketPlaceholder), findsNWidgets(2));

    await tester.tap(find.byType(TicketPlaceholder).last);
    await tester.pump();
    expect(started?.concertId, 'c2');
    expect(tester.takeException(), isNull);
  });
}
