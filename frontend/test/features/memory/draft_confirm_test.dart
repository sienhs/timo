import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/memory/constants.dart';
import 'package:timo/features/memory/data/ticket_store.dart';
import 'package:timo/features/memory/models/memory_ticket.dart';
import 'package:timo/features/memory/screens/memory_ticket_screen.dart';
import 'package:timo/features/memory/state/ticket_store_scope.dart';
import 'package:timo/features/memory/state/tilt_setting_scope.dart';
import 'package:timo/features/memory/data/tilt_setting.dart';
import 'package:timo/features/memory/theme/memory_theme.dart';
import 'package:timo/features/memory/widgets/collection/ticket_thumbnail.dart';

const _draft = MemoryTicket(
  ticketId: 'ticket-1024',
  concertId: 'concert-1024',
  backgroundPath: '/none/background.png',
  personCompositePath: null,
  effectType: '효과 없음',
  videoId: 'concert-1024-main',
  videoUrl: '',
  details: {'공연명': '빛으로 남은 밤', '날짜': '2026.09.26'},
  depthLayers: [],
  demoDepth: false,
);

Widget _viewer(TicketStore store, MemoryTicket ticket) => MaterialApp(
  theme: timoDarkTheme(),
  home: MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: TicketStoreScope(
      store: store,
      child: TiltSettingScope(
        setting: TiltSetting(InMemoryTiltSettingStore()),
        child: MemoryTicketScreen(ticket: ticket),
      ),
    ),
  ),
);

void main() {
  test('새로 만든 소장품은 확정 전이고, 저장되면 그대로 읽힌다', () {
    expect(_draft.confirmed, isFalse);
    expect(MemoryTicket.fromJson(_draft.toJson()).confirmed, isFalse);
  });

  test('확정 개념이 생기기 전에 저장된 것은 확정본으로 읽는다', () {
    final old = _draft.toJson()..remove('confirmed');
    expect(MemoryTicket.fromJson(old).confirmed, isTrue);
  });

  testWidgets('확정 전 소장품에는 임시 딱지가 붙는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: timoDarkTheme(),
        home: Center(
          child: SizedBox(
            width: 200,
            height: 300,
            child: TicketThumbnail(ticket: _draft),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(CollectionText.draftBadge), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: timoDarkTheme(),
        home: Center(
          child: SizedBox(
            width: 200,
            height: 300,
            child: TicketThumbnail(ticket: _draft.copyWith(confirmed: true)),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(CollectionText.draftBadge), findsNothing);
  });

  testWidgets('확정하면 저장되고 확정 줄이 사라진다', (tester) async {
    final store = InMemoryTicketStore();
    await store.save(_draft);
    await tester.pumpWidget(_viewer(store, _draft));
    await tester.pump();

    expect(find.text(ViewerText.draftNote), findsOneWidget);
    // 확정 전에는 내보낼 수 없다.
    expect(find.byTooltip(ShareText.shareTooltip), findsNothing);

    await tester.tap(find.text(ViewerText.confirmLabel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text(ViewerText.confirmOk));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(store.readAll().single.confirmed, isTrue);
    expect(find.text(ViewerText.draftNote), findsNothing);
    expect(find.byTooltip(ShareText.shareTooltip), findsOneWidget);
  });

  testWidgets('확정한 소장품에는 확정 줄이 없다', (tester) async {
    final confirmed = _draft.copyWith(confirmed: true);
    await tester.pumpWidget(_viewer(InMemoryTicketStore(), confirmed));
    await tester.pump();

    expect(find.text(ViewerText.draftNote), findsNothing);
    expect(find.text(ViewerText.confirmLabel), findsNothing);
  });
}
