import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/ticket/data/ticket_api.dart';
import 'package:timo/features/ticket/models/entry_pass.dart';
import 'package:timo/features/ticket/models/my_ticket.dart';
import 'package:timo/features/ticket/models/reservation_detail.dart';
import 'package:timo/features/ticket/models/ticket_acquisition.dart';
import 'package:timo/features/ticket/models/ticket_status.dart';
import 'package:timo/features/ticket/screens/entry_qr_screen.dart';
import 'package:timo/features/ticket/screens/quick_entry_qr_screen.dart';
import 'package:timo/features/ticket/state/ticket_api_scope.dart';
import 'package:timo/features/shell/constants.dart';
import 'package:timo/routes/app_routes.dart';

void main() {
  final now = DateTime(2026, 9, 22, 18);

  MyTicket ticket(int id, {TicketStatus status = TicketStatus.owned}) =>
      MyTicket(
        ticketId: id,
        reservationId: id,
        concertId: 1,
        title: '공연 $id',
        venueName: '공연장',
        sectionName: 'R석',
        seatRow: 1,
        seatNumber: id,
        facePrice: 10000,
        status: status,
        listed: false,
        acquiredBy: TicketAcquisition.booking,
        acquiredAt: now.subtract(const Duration(days: 1)),
        startAt: now.add(const Duration(hours: 1)),
      );

  Future<void> pumpQuickMenuRoute(WidgetTester tester, _TicketApi api) async {
    await tester.pumpWidget(
      TicketApiScope(
        api: api,
        child: MaterialApp(
          home: QuickEntryQrScreen(clock: () => now),
          routes: {AppRoutes.entryQr: AppRoutes.routes[AppRoutes.entryQr]!},
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('입장 가능한 티켓이 한 장이면 QR 화면을 바로 연다', (tester) async {
    expect(quickMenuItems.first.routeName, AppRoutes.entryQr);
    final api = _TicketApi([ticket(1), ticket(2, status: TicketStatus.used)]);
    await pumpQuickMenuRoute(tester, api);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.byType(EntryQrScreen), findsOneWidget);
    expect(api.issuedTicketIds, [1]);
  });

  testWidgets('입장 가능한 티켓이 여러 장이면 고를 수 있다', (tester) async {
    final api = _TicketApi([ticket(1), ticket(2)]);
    await pumpQuickMenuRoute(tester, api);

    expect(find.text('입장할 티켓을 선택해주세요.'), findsOneWidget);
    await tester.tap(find.text('공연 2'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(api.issuedTicketIds, [2]);
  });
}

class _TicketApi implements TicketApi {
  _TicketApi(this.tickets);

  final List<MyTicket> tickets;
  final issuedTicketIds = <int>[];

  @override
  Future<List<MyTicket>> fetchMyTickets() async => tickets;

  @override
  Future<EntryPass> issueEntryPass(int ticketId) async {
    issuedTicketIds.add(ticketId);
    return EntryPass(
      token: 'test-pass-$ticketId',
      lifetime: const Duration(seconds: 30),
      receivedAt: DateTime.now(),
    );
  }

  @override
  Future<void> cancelReservation(int reservationId) =>
      throw UnimplementedError();

  @override
  Future<ReservationDetail> createReservation({
    required int concertId,
    required int seatId,
  }) => throw UnimplementedError();

  @override
  Future<ReservationDetail> fetchReservation(int reservationId) =>
      throw UnimplementedError();
}
