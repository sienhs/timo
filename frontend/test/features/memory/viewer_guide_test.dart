import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/memory/constants.dart';
import 'package:timo/features/memory/data/goods_api.dart';
import 'package:timo/features/memory/data/ticket_store.dart';
import 'package:timo/features/memory/data/tilt_setting.dart';
import 'package:timo/features/memory/data/viewer_guide_setting.dart';
import 'package:timo/features/memory/models/memory_ticket.dart';
import 'package:timo/features/memory/screens/memory_ticket_screen.dart';
import 'package:timo/features/memory/state/goods_api_scope.dart';
import 'package:timo/features/memory/state/ticket_store_scope.dart';
import 'package:timo/features/memory/state/tilt_setting_scope.dart';
import 'package:timo/features/memory/state/viewer_guide_scope.dart';
import 'package:timo/features/memory/theme/memory_theme.dart';

const _ticket = MemoryTicket(
  ticketId: '226',
  concertId: '3',
  backgroundPath: '/none/background.png',
  personCompositePath: null,
  effectType: '효과 없음',
  videoId: 'v',
  videoUrl: '',
  details: {'공연명': '로이킴 콘서트'},
  depthLayers: [],
  demoDepth: true,
  confirmed: true,
);

Widget _viewer(ViewerGuideSetting guide) => MaterialApp(
  theme: timoDarkTheme(),
  home: MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: TicketStoreScope(
      store: InMemoryTicketStore(),
      child: GoodsApiScope(
        api: MockGoodsApi(),
        // 기울임을 꺼 둔다. 켜 두면 카드가 센서 채널을 연다.
        child: TiltSettingScope(
          setting: TiltSetting(InMemoryTiltSettingStore())..toggle(),
          child: ViewerGuideScope(
            setting: guide,
            child: const MemoryTicketScreen(ticket: _ticket),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('처음 열면 조작법 안내가 뜨고, 닫으면 본 것으로 남는다', (tester) async {
    final store = InMemoryViewerGuideStore();
    await tester.pumpWidget(_viewer(ViewerGuideSetting(store)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(ViewerText.guideTitle), findsOneWidget);
    expect(find.text(ViewerText.guideSwipe), findsOneWidget);
    expect(find.text(ViewerText.guideHold), findsOneWidget);

    await tester.tap(find.text(ViewerText.guideOk));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(ViewerText.guideTitle), findsNothing);
    expect(store.seen, isTrue);
  });

  testWidgets('이미 봤으면 뜨지 않고, ? 를 누르면 다시 볼 수 있다', (tester) async {
    await tester.pumpWidget(
      _viewer(
        ViewerGuideSetting(InMemoryViewerGuideStore(true), alreadySeen: true),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(ViewerText.guideTitle), findsNothing);
    // 조작법·처리 내역이 화면에 늘 적혀 있지 않다.
    expect(find.text(ViewerText.guideSwipe), findsNothing);
    expect(find.textContaining('Depth Anything'), findsNothing);

    await tester.tap(find.byTooltip(ViewerText.guideTooltip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(ViewerText.guideTitle), findsOneWidget);
  });
}
