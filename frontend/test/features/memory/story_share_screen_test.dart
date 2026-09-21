import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/memory/constants.dart';
import 'package:timo/features/memory/models/memory_ticket.dart';
import 'package:timo/features/memory/screens/story_share_screen.dart';
import 'package:timo/features/memory/theme/memory_theme.dart';
import 'package:timo/features/memory/utils/palette_extractor.dart';
import 'package:timo/features/memory/widgets/share/story_stage.dart';
import 'package:timo/features/memory/widgets/viewer/memory_ticket_card.dart';

const _ticket = MemoryTicket(
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

Widget _app() => MaterialApp(
  theme: timoDarkTheme(),
  home: const MediaQuery(
    data: MediaQueryData(disableAnimations: true),
    child: StoryShareScreen(ticket: _ticket, palette: TicketPalette.fallback),
  ),
);

/// 카드는 살아 있는 티커를 물고 있어 결코 멈추지 않는다. pumpAndSettle 은 여기서
/// 영영 끝나지 않으므로, 올리는 동안만큼만 시간을 흘려보낸다.
Future<void> _post(WidgetTester tester) async {
  await tester.tap(find.text(ShareText.post));
  await tester.pump();
  await tester.pump(ShareLayout.uploadDuration);
  await tester.pump();
}

void main() {
  testWidgets('올리기 전에는 미리보기가 센서를 잡지 않는다', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    expect(find.text(ShareText.post), findsOneWidget);
    expect(find.text(ShareText.tiltOption), findsOneWidget);
    expect(
      tester
          .widget<MemoryTicketCard>(find.byType(MemoryTicketCard))
          .tiltBySensor,
      isFalse,
    );
  });

  testWidgets('공유하면 스토리가 올라가고, 켜 둔 기울임이 스토리에 적용된다', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    await _post(tester);

    // 스토리는 화면 전체를 쓴다 — 올리기 전의 앱 막대가 남아 있으면 안 된다.
    expect(find.text(ShareText.title), findsNothing);
    expect(find.byType(StoryStage), findsOneWidget);
    expect(find.text(ShareText.tiltHint), findsOneWidget);
    expect(
      tester
          .widget<MemoryTicketCard>(find.byType(MemoryTicketCard))
          .tiltBySensor,
      isTrue,
    );
  });

  testWidgets('기울임을 끄고 올리면 스토리도 고정된 그림이다', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    await tester.tap(find.byType(Switch));
    await tester.pump();
    await _post(tester);

    expect(find.text(ShareText.tiltHint), findsNothing);
    expect(
      tester
          .widget<MemoryTicketCard>(find.byType(MemoryTicketCard))
          .tiltBySensor,
      isFalse,
    );
  });
}
