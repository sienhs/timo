import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/ticket/models/my_ticket.dart';
import 'package:timo/features/ticket/models/ticket_acquisition.dart';
import 'package:timo/features/ticket/models/ticket_status.dart';

/// 내 티켓 한 장의 판정. 서버가 준 티켓 상태·등록 여부·취득 경로가 버튼을
/// 어떻게 잠그는지 본다.
void main() {
  final now = DateTime(2026, 9, 15, 14);

  /// 서버 내 티켓 목록 응답 한 건. 실제 `MyTicketSummaryResponseDto` 모양이다.
  Map<String, dynamic> json({
    String ticketStatus = 'OWNED',
    bool listed = false,
    String acquiredBy = 'BOOKING',
    String? startDate = '2026-09-24T19:00:00',
  }) => {
    'ticketId': 101,
    'reservationId': 1,
    'concertId': 11,
    'concertTitle': '2026 REMIND: 리센느',
    'posterImageUrl': 'poster/remind.gif',
    'startDate': startDate,
    'venueName': '올림픽공원 체조경기장',
    'sectionName': 'R석',
    'seatNo': 12,
    'seatCol': 24,
    'facePrice': 154000,
    'ticketStatus': ticketStatus,
    'acquiredBy': acquiredBy,
    'acquiredAt': '2026-09-01T20:05:00',
    'listed': listed,
  };

  MyTicket ticket({
    TicketStatus status = TicketStatus.owned,
    bool listed = false,
    TicketAcquisition acquiredBy = TicketAcquisition.booking,
    DateTime? startAt,
  }) => MyTicket(
    ticketId: 101,
    reservationId: 1,
    concertId: 11,
    title: '2026 REMIND: 리센느',
    venueName: '올림픽공원 체조경기장',
    sectionName: 'R석',
    seatRow: 12,
    seatNumber: 24,
    facePrice: 154000,
    status: status,
    listed: listed,
    acquiredBy: acquiredBy,
    acquiredAt: DateTime(2026, 9, 1, 20, 5),
    startAt: startAt ?? DateTime(2026, 9, 24, 19),
  );

  group('서버 응답 읽기', () {
    test('티켓 번호가 주 식별자고 예매 번호는 따로 든다', () {
      final ticket = MyTicket.fromJson(json());

      expect(ticket.ticketId, 101);
      expect(ticket.reservationId, 1);
      expect(ticket.title, '2026 REMIND: 리센느');
      expect(ticket.facePrice, 154000);
      expect(ticket.startAt, DateTime(2026, 9, 24, 19));
    });

    test('티켓 상태·등록 여부·취득 경로·취득 시각을 읽는다', () {
      final ticket = MyTicket.fromJson(
        json(ticketStatus: 'LISTED', listed: true, acquiredBy: 'TRANSFER'),
      );

      expect(ticket.status, TicketStatus.listed);
      expect(ticket.listed, isTrue);
      expect(ticket.acquiredBy, TicketAcquisition.transfer);
      expect(ticket.acquiredAt, DateTime(2026, 9, 1, 20, 5));
    });

    // 이름이 직관과 반대라 뒤집혀 들어가기 쉬운 자리다.
    test('seatNo 가 열, seatCol 이 번으로 들어간다', () {
      final ticket = MyTicket.fromJson(json());

      expect(ticket.seatRow, 12);
      expect(ticket.seatNumber, 24);
      expect(ticket.seatLabel, 'R석 12열 24번');
    });

    // 서버에 상태가 하나 늘어도 목록 전체가 깨지면 안 된다. 그 카드만 잠근다.
    test('모르는 상태와 취득 경로는 알 수 없음으로 본다', () {
      final ticket = MyTicket.fromJson(
        json(ticketStatus: 'BURNED', acquiredBy: 'GIFT'),
      );

      expect(ticket.status, TicketStatus.unknown);
      expect(ticket.acquiredBy, TicketAcquisition.unknown);
      expect(ticket.isUsable, isFalse);
      expect(ticket.isBooked, isFalse);
    });

    test('공연 날짜가 없어도 읽는다', () {
      expect(MyTicket.fromJson(json(startDate: null)).startAt, isNull);
    });
  });

  group('양도 등록 중', () {
    // 서버는 매물 테이블을 본 `listed` 와 상태값을 둘 다 준다. 둘 중 하나만
    // 켜져 있어도 등록 중이다.
    test('listed 가 켜졌거나 상태가 양도 등록됨이면 등록 중이다', () {
      expect(ticket(listed: true).isListed, isTrue);
      expect(ticket(status: TicketStatus.listed).isListed, isTrue);
      expect(ticket().isListed, isFalse);
    });

    test('등록 중이면 손에 있어도 쓸 수 없다', () {
      expect(ticket(listed: true).isUsable, isFalse);
    });
  });

  group('쓸 수 있는 상태', () {
    test('보유이고 등록 중이 아닐 때만 쓸 수 있다', () {
      expect(ticket().isUsable, isTrue);
      for (final status in [
        TicketStatus.pendingMint,
        TicketStatus.mintFailed,
        TicketStatus.refunded,
        TicketStatus.listed,
        TicketStatus.used,
        TicketStatus.revoked,
        TicketStatus.unknown,
      ]) {
        expect(ticket(status: status).isUsable, isFalse, reason: '$status');
      }
    });

    test('회수·환불이 사라진 상태다', () {
      expect(ticket(status: TicketStatus.revoked).isVoided, isTrue);
      expect(ticket(status: TicketStatus.refunded).isVoided, isTrue);
      expect(ticket(status: TicketStatus.used).isVoided, isFalse);
      expect(ticket().isVoided, isFalse);
    });
  });

  group('입장 QR', () {
    final soon = now.add(const Duration(hours: 1));

    test('보유 티켓은 공연 시간대에 열린다', () {
      expect(ticket(startAt: soon).canEnter(now), isTrue);
    });

    // 서버가 409 로 거절하는 상태다. 눌러 보고 알게 하지 않는다.
    test('등록 중·발행 중·입장 완료는 시간대라도 잠긴다', () {
      expect(ticket(startAt: soon, listed: true).canEnter(now), isFalse);
      expect(
        ticket(startAt: soon, status: TicketStatus.pendingMint).canEnter(now),
        isFalse,
      );
      expect(
        ticket(startAt: soon, status: TicketStatus.used).canEnter(now),
        isFalse,
      );
    });
  });

  group('예매 취소', () {
    test('직접 예매한 보유 티켓은 24시간 전까지 취소할 수 있다', () {
      expect(ticket().canCancel(now), isTrue);
      expect(
        ticket(startAt: now.add(const Duration(hours: 23))).canCancel(now),
        isFalse,
      );
    });

    // 예매 행이 판 사람 것이라 요청해도 404 다. 서버가 그래서 취득 경로를 준다.
    test('양도로 받은 티켓은 취소할 수 없다', () {
      expect(
        ticket(acquiredBy: TicketAcquisition.transfer).canCancel(now),
        isFalse,
      );
    });

    test('등록 중인 티켓은 취소할 수 없다', () {
      expect(ticket(listed: true).canCancel(now), isFalse);
    });
  });

  test('상태와 등록 여부만 바꾼 사본을 만든다', () {
    final copy = ticket().copyWith(status: TicketStatus.revoked, listed: true);

    expect(copy.status, TicketStatus.revoked);
    expect(copy.listed, isTrue);
    expect(copy.ticketId, 101);
    expect(copy.acquiredBy, TicketAcquisition.booking);
  });
}
