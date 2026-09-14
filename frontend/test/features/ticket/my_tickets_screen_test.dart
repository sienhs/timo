import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/ticket/constants.dart';
import 'package:timo/features/ticket/data/mock_ticket_api.dart';
import 'package:timo/features/ticket/data/ticket_api.dart';
import 'package:timo/features/ticket/models/my_ticket.dart';
import 'package:timo/features/ticket/screens/my_tickets_screen.dart';
import 'package:timo/features/ticket/state/ticket_api_scope.dart';
import 'package:timo/features/ticket/widgets/past_ticket_card.dart';
import 'package:timo/features/ticket/widgets/ticket_list_skeleton.dart';
import 'package:timo/features/ticket/widgets/upcoming_ticket_card.dart';

void main() {
  /// 화면을 목과 함께 띄운다. 지연은 0 이라 한 번 더 pump 하면 목록이 나온다.
  Future<void> pumpScreen(
    WidgetTester tester, {
    TicketApi? api,
    TicketMockScenario scenario = TicketMockScenario.design,
  }) async {
    await tester.pumpWidget(
      TicketApiScope(
        api: api ?? MockTicketApi(latency: Duration.zero, scenario: scenario),
        child: const MaterialApp(home: MyTicketsScreen()),
      ),
    );
  }

  group('탭과 목록', () {
    testWidgets('예정 탭이 먼저 열리고 예정 공연만 나온다', (tester) async {
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      // 시안 데이터는 예정 2장 · 지난 2장이다.
      expect(find.byType(UpcomingTicketCard), findsNWidgets(2));
      expect(find.byType(PastTicketCard), findsNothing);
      expect(find.text('2026 REMIND: 리센느'), findsOneWidget);
      expect(find.text('2026 아이유 콘서트'), findsOneWidget);
    });

    testWidgets('탭 옆에 개수가 붙는다', (tester) async {
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('${TicketStrings.tabUpcoming} 2'), findsOneWidget);
      expect(find.text('${TicketStrings.tabPast} 2'), findsOneWidget);
    });

    testWidgets('지난 공연 탭을 누르면 지난 공연만 나온다', (tester) async {
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('${TicketStrings.tabPast} 2'));
      await tester.pumpAndSettle();

      expect(find.byType(PastTicketCard), findsNWidgets(2));
      expect(find.byType(UpcomingTicketCard), findsNothing);
      expect(find.text('2025 블랙핑크'), findsOneWidget);
    });
  });

  group('예정 카드의 버튼', () {
    // 시안에서 카드마다 버튼이 다른 이유다. 공연 시간대에 들어온 티켓만 QR 이 열린다.
    testWidgets('공연이 곧 시작하면 입장 QR, 아니면 상세정보', (tester) async {
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text(TicketStrings.enterQr), findsOneWidget);
      expect(find.text(TicketStrings.showDetail), findsOneWidget);
      // QR 이 안 열린 카드에는 그 이유가 한 줄 붙는다.
      expect(find.text(TicketStrings.qrOpensOnShowDay), findsOneWidget);
    });

    testWidgets('D-day 배지가 남은 날만큼 찍힌다', (tester) async {
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      // 목의 두 티켓은 각각 오늘과 9일 뒤다.
      expect(find.text('D-DAY'), findsOneWidget);
      expect(find.text('D-9'), findsOneWidget);
    });
  });

  group('발행 상태', () {
    testWidgets('발행 중·실패·환불·취소가 버튼 대신 안내로 나온다', (tester) async {
      await pumpScreen(tester, scenario: TicketMockScenario.states);
      await tester.pumpAndSettle();

      expect(find.text(TicketStrings.issuingNotice), findsOneWidget);
      expect(find.text(TicketStrings.mintFailedNotice), findsOneWidget);

      // 카드 넷이 한 화면에 안 들어가 뒤쪽은 아직 안 그려졌다. 끌어 내려서 본다.
      for (final notice in [
        TicketStrings.refundedNotice,
        TicketStrings.cancelledNotice,
      ]) {
        await tester.scrollUntilVisible(find.text(notice), 200);
        expect(find.text(notice), findsOneWidget);
      }

      // 이 상태들에서는 입장도 상세도 눌릴 자리가 없다.
      expect(find.text(TicketStrings.enterQr), findsNothing);
      expect(find.text(TicketStrings.showDetail), findsNothing);
    });

    testWidgets('발행 중 배지가 붙는다', (tester) async {
      await pumpScreen(tester, scenario: TicketMockScenario.states);
      await tester.pumpAndSettle();

      expect(find.text(TicketStrings.issuingBadge), findsOneWidget);
    });

    // 회수된 티켓은 예정 탭에 남는다. 지난 공연 탭에 섞이면 다녀온 공연으로 읽힌다.
    testWidgets('취소·환불된 티켓은 지난 공연 탭에 안 간다', (tester) async {
      await pumpScreen(tester, scenario: TicketMockScenario.states);
      await tester.pumpAndSettle();

      expect(find.text('${TicketStrings.tabUpcoming} 4'), findsOneWidget);
      expect(find.text('${TicketStrings.tabPast} 0'), findsOneWidget);
    });
  });

  group('빈 목록과 실패', () {
    testWidgets('탭마다 다른 빈 상태 문구가 나온다', (tester) async {
      await pumpScreen(tester, scenario: TicketMockScenario.empty);
      await tester.pumpAndSettle();

      expect(find.text(TicketStrings.emptyUpcoming), findsOneWidget);
      expect(find.text(TicketStrings.emptyUpcomingAction), findsOneWidget);

      await tester.tap(find.text('${TicketStrings.tabPast} 0'));
      await tester.pumpAndSettle();
      expect(find.text(TicketStrings.emptyPast), findsOneWidget);
    });

    testWidgets('불러오는 동안 뼈대 카드를 세운다', (tester) async {
      await pumpScreen(
        tester,
        api: MockTicketApi(latency: const Duration(milliseconds: 100)),
      );
      await tester.pump();

      expect(find.byType(TicketListSkeleton), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(TicketListSkeleton), findsNothing);
    });

    testWidgets('실패하면 문구와 다시 시도가 나온다', (tester) async {
      await pumpScreen(tester, scenario: TicketMockScenario.error);
      await tester.pumpAndSettle();

      expect(find.text('인터넷 연결을 확인해주세요.'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    });
  });

  group('검색', () {
    // 티켓이 적으면 두 줄을 눈으로 훑는 편이 빠르다. 시안은 2장짜리 목록 위에도 검색을 뒀다.
    testWidgets('티켓이 적으면 검색 칸을 안 낸다', (tester) async {
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('많아지면 검색 칸이 나오고 제목으로 걸러진다', (tester) async {
      await pumpScreen(tester, api: _ManyTicketsApi());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), '아이유');
      await tester.pumpAndSettle();

      expect(find.byType(UpcomingTicketCard), findsOneWidget);
      expect(find.text('2026 아이유 콘서트'), findsOneWidget);
    });

    testWidgets('걸러서 비면 찾는 게 없다고 알린다', (tester) async {
      await pumpScreen(tester, api: _ManyTicketsApi());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '없는공연');
      await tester.pumpAndSettle();

      expect(find.text(TicketStrings.searchEmpty('없는공연')), findsOneWidget);
      expect(find.text(TicketStrings.emptyUpcoming), findsNothing);
    });
  });
}

/// 검색 칸이 나올 만큼(5장 이상) 예정 티켓을 주는 목.
///
/// 시나리오로 만들지 않은 이유: 검색 칸이 뜨는 경계를 보려고 만든 데이터라
/// 앱에서 골라 볼 일이 없다. `MockTicketApi` 에 두면 실행 인자만 늘어난다.
class _ManyTicketsApi implements TicketApi {
  final _base = MockTicketApi(latency: Duration.zero);

  @override
  Future<List<MyTicket>> fetchMyTickets() async {
    final tickets = await _base.fetchMyTickets();
    final upcoming = tickets.take(2).toList();
    return [...upcoming, for (var i = 0; i < 4; i++) upcoming.first.copyWith()];
  }

  @override
  Future<void> cancelReservation(int reservationId) =>
      _base.cancelReservation(reservationId);
}
