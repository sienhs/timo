import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/network/api_exception.dart';
import 'package:timo/core/widgets/error_snack_bar.dart';
import 'package:timo/features/auth/data/mock_auth_api.dart';
import 'package:timo/features/auth/data/token_storage.dart';
import 'package:timo/features/auth/state/auth_session.dart';
import 'package:timo/features/auth/state/auth_session_scope.dart';
import 'package:timo/features/resale/data/mock_resale_api.dart';
import 'package:timo/features/resale/state/resale_api_scope.dart';
import 'package:timo/features/ticket/constants.dart';
import 'package:timo/features/ticket/data/mock_ticket_api.dart';
import 'package:timo/features/ticket/data/ticket_api.dart';
import 'package:timo/features/ticket/models/entry_pass.dart';
import 'package:timo/features/ticket/models/my_ticket.dart';
import 'package:timo/features/ticket/models/reservation_detail.dart';
import 'package:timo/features/ticket/screens/my_tickets_screen.dart';
import 'package:timo/features/ticket/state/ticket_api_scope.dart';

void main() {
  /// 화면이 로그인 세션을 보고 목록을 부르므로 로그인한 세션을 함께 내려준다.
  Future<void> pumpScreen(WidgetTester tester, {TicketApi? api}) async {
    final session = AuthSession(storage: InMemoryTokenStorage());
    await session.signIn(MockAuthApi.tokens);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      AuthSessionScope(
        session: session,
        child: TicketApiScope(
          api: api ?? MockTicketApi(latency: Duration.zero),
          // 화면이 양도 목록 탭 때문에 마켓 API 도 부른다. 이 테스트는 그 탭을
          // 안 보지만 스코프가 없으면 화면이 서지 않는다.
          child: ResaleApiScope(
            api: MockResaleApi(latency: Duration.zero),
            child: const MaterialApp(home: MyTicketsScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 아이유 카드(9일 뒤 공연)의 더보기를 연다. 목의 두 예정 티켓 중 취소가
  /// 되는 쪽이다 — 리센느는 1시간 뒤라 24시간 규칙에 걸린다.
  Future<void> openMore(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
  }

  group('더보기', () {
    testWidgets('취소가 되는 티켓에만 더보기가 붙는다', (tester) async {
      await pumpScreen(tester);

      // 리센느는 공연이 1시간 뒤라 취소 기한이 지났지만, 이유를 알려주려고
      // 더보기 자체는 연다.
      expect(find.byIcon(Icons.more_vert), findsNWidgets(2));
    });

    testWidgets('더보기를 누르면 예매 취소하기가 나온다', (tester) async {
      await pumpScreen(tester);
      await openMore(tester);

      expect(find.text(TicketStrings.cancelReservation), findsOneWidget);
    });

    // 시트는 여는 데 한 프레임이 걸려서, 그 사이 한 번 더 눌리면 두 장이
    // 겹친다. pump 없이 이어 눌러 그 순간을 만든다.
    testWidgets('빨리 두 번 눌러도 시트는 한 장만 열린다', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      expect(find.text(TicketStrings.cancelReservation), findsOneWidget);
    });

    // 공연이 코앞이면 취소가 막힌다. 항목을 지우면 왜 못 하는지 알 길이 없다.
    testWidgets('24시간 이내 공연은 항목이 잠기고 이유가 붙는다', (tester) async {
      await pumpScreen(tester);

      // 첫 카드(리센느)가 1시간 뒤 공연이다.
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      expect(find.text(TicketStrings.cancelTooLate), findsOneWidget);
      // 시트에 양도 등록 항목도 있으므로 취소 항목만 집어 본다.
      final tile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, TicketStrings.cancelReservation),
      );
      expect(tile.enabled, isFalse);
    });
  });

  group('확인 팝업', () {
    testWidgets('무엇을 취소하는지와 환불 금액을 보여준다', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.byIcon(Icons.more_vert).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(TicketStrings.cancelReservation));
      await tester.pumpAndSettle();

      // 좌석은 뒤에 깔린 카드에도 있으므로 팝업 안에서만 찾는다.
      Finder inDialog(String text) =>
          find.descendant(of: find.byType(Dialog), matching: find.text(text));

      expect(find.text(TicketStrings.cancelConfirmTitle), findsOneWidget);
      expect(inDialog('2026 아이유 콘서트'), findsOneWidget);
      expect(inDialog('VIP석 5열 10번'), findsOneWidget);
      expect(
        inDialog(TicketStrings.refundAmount('198,000 MSR')),
        findsOneWidget,
      );
    });

    testWidgets('그대로 두면 아무 일도 안 일어난다', (tester) async {
      final api = _SpyApi();
      await pumpScreen(tester, api: api);
      await tester.tap(find.byIcon(Icons.more_vert).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(TicketStrings.cancelReservation));
      await tester.pumpAndSettle();

      await tester.tap(find.text(TicketStrings.cancelConfirmKeep));
      await tester.pumpAndSettle();

      expect(api.cancelled, isEmpty);
    });
  });

  group('취소 실행', () {
    testWidgets('취소하면 서버에 보내고 회색 카드로 남는다', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.byIcon(Icons.more_vert).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(TicketStrings.cancelReservation));
      await tester.pumpAndSettle();
      await tester.tap(find.text(TicketStrings.cancelConfirmAgree));
      await tester.pumpAndSettle();

      // 목록에서 지우지 않는다. 취소 결과를 눈으로 봐야 한다.
      expect(find.text('2026 아이유 콘서트'), findsOneWidget);
      expect(find.text(TicketStrings.cancelledNotice), findsOneWidget);
      expect(find.text('${TicketStrings.tabUpcoming} 2'), findsOneWidget);
    });

    // 화면이 미리 걸러도 시점 차이로 통과할 수 있다. 최종 판정은 서버 몫이다.
    testWidgets('서버가 거절하면 그 문구를 띄우고 목록은 그대로다', (tester) async {
      final api = _SpyApi(
        failure: const ApiException('공연 시작 24시간 이내에는 취소할 수 없습니다.', status: 409),
      );
      await pumpScreen(tester, api: api);
      await tester.tap(find.byIcon(Icons.more_vert).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(TicketStrings.cancelReservation));
      await tester.pumpAndSettle();
      await tester.tap(find.text(TicketStrings.cancelConfirmAgree));
      await tester.pumpAndSettle();

      expect(
        find.text(toastText('공연 시작 24시간 이내에는 취소할 수 없습니다.')),
        findsOneWidget,
      );
      expect(find.text(TicketStrings.cancelledNotice), findsNothing);
    });
  });
}

/// 취소 요청이 나갔는지 지켜보는 목. 실패를 넣으면 그걸 던진다.
class _SpyApi implements TicketApi {
  _SpyApi({this.failure});

  final ApiException? failure;
  final cancelled = <int>[];

  final _base = MockTicketApi(latency: Duration.zero);

  @override
  Future<void> cancelReservation(int reservationId) async {
    if (failure case final failure?) throw failure;
    cancelled.add(reservationId);
    await _base.cancelReservation(reservationId);
  }

  @override
  Future<List<MyTicket>> fetchMyTickets() => _base.fetchMyTickets();

  @override
  Future<ReservationDetail> createReservation({
    required int concertId,
    required int seatId,
  }) => _base.createReservation(concertId: concertId, seatId: seatId);

  @override
  Future<ReservationDetail> fetchReservation(int reservationId) =>
      _base.fetchReservation(reservationId);

  @override
  Future<EntryPass> issueEntryPass(int ticketId) =>
      _base.issueEntryPass(ticketId);
}
