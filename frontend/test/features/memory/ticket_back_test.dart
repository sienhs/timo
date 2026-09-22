import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/memory/models/memory_ticket.dart';
import 'package:timo/features/memory/theme/memory_theme.dart';
import 'package:timo/features/memory/widgets/viewer/ticket_back.dart';

MemoryTicket _ticket(String ticketId) => MemoryTicket(
  ticketId: ticketId,
  concertId: '3',
  backgroundPath: '/none/bg.png',
  personCompositePath: null,
  effectType: '효과 없음',
  videoId: 'v',
  videoUrl: '',
  details: const {
    '공연명': '빛으로 남은 밤',
    '아티스트': 'TIMO STAGE',
    '날짜': '2026.09.26',
    '시간': '19:00',
    '장소': '서울 메모리 홀',
  },
  depthLayers: const [],
  demoDepth: true,
);

Widget _back(MemoryTicket ticket) => MaterialApp(
  theme: timoDarkTheme(),
  home: Center(
    child: SizedBox(
      width: 320,
      height: 500,
      child: TicketBack(
        ticket: ticket,
        tilt: ValueNotifier(Offset.zero),
        time: ValueNotifier(0),
      ),
    ),
  ),
);

void main() {
  testWidgets('서버 티켓 번호처럼 짧은 번호도 뒷면이 그려진다', (tester) async {
    // 예전 목 번호(`ticket-1024`)만 보고 끝 여섯 자리를 잘라 내던 것이
    // 세 자리 번호에서 RangeError 로 터져 카드 전체가 회색이 됐다.
    await tester.pumpWidget(_back(_ticket('124')));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('#124'), findsOneWidget);
    expect(find.text('빛으로 남은 밤'), findsOneWidget);
  });

  testWidgets('긴 번호는 끝 여섯 자리만 적는다', (tester) async {
    await tester.pumpWidget(_back(_ticket('ticket-1024')));
    await tester.pump();

    expect(find.text('#t-1024'), findsOneWidget);
  });
}
