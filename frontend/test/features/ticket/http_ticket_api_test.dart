import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/network/api_exception.dart';
import 'package:timo/features/ticket/data/http_ticket_api.dart';
import 'package:timo/features/ticket/models/reservation_detail.dart';
import 'package:timo/features/ticket/models/reservation_status.dart';
import 'package:timo/features/ticket/models/ticket_acquisition.dart';
import 'package:timo/features/ticket/models/ticket_status.dart';

import '../../core/network/fake_http_adapter.dart';

/// 티켓·예매 v1 API 에 맞는 요청이 나가고 응답을 제대로 읽는지.
/// 서버 없이 [FakeHttpAdapter] 로 검사한다.
void main() {
  late FakeHttpAdapter adapter;
  late HttpTicketApi api;

  /// [handler] 가 돌려주는 응답으로 가짜 서버를 세운다. [clock] 은 입장 QR 을
  /// 받은 시각을 고정할 때만 넘긴다.
  void givenServer(
    FutureOr<ResponseBody> Function(RecordedRequest) handler, {
    DateTime Function()? clock,
  }) {
    adapter = FakeHttpAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'http://fake.test'))
      ..httpClientAdapter = adapter;
    api = HttpTicketApi(dio: dio, clock: clock);
  }

  /// 서버 내 티켓 목록 응답 한 건. 실제 `MyTicketSummaryResponseDto` 모양이다.
  /// 필드 이름은 예매 목록과 같고, 티켓 상태·등록 여부·취득 경로·취득 시각이
  /// 더 있다.
  Map<String, dynamic> myTicketJson({
    int ticketId = 101,
    String ticketStatus = 'OWNED',
    bool listed = false,
    String acquiredBy = 'BOOKING',
    String? startDate = '2026-10-10T19:00:00',
  }) => {
    'ticketId': ticketId,
    // 이 티켓을 발행한 예매. 양도로 받았으면 판 사람 것이다.
    'reservationId': ticketId - 100,
    'concertId': 11,
    'concertTitle': '2026 REMIND: 리센느',
    'posterImageUrl': 'poster/remind.gif',
    'startDate': startDate,
    'venueName': '올림픽공원 체조경기장',
    'sectionName': 'R석',
    // seatNo 가 행(열), seatCol 이 그 행 안의 자리 번호다.
    'seatNo': 12,
    'seatCol': 24,
    'facePrice': 154000,
    'ticketStatus': ticketStatus,
    'acquiredBy': acquiredBy,
    'acquiredAt': '2026-09-01T20:05:00',
    'listed': listed,
  };

  /// 서버 예매 목록 응답 한 건. 실제 `ReservationSummaryResponseDto` 모양이다.
  /// 예매 취소가 이 모양을 돌려준다.
  Map<String, dynamic> reservationJson({int id = 1, String status = 'PAID'}) =>
      {
        'id': id,
        'ticketId': 100 + id,
        'concertId': 11,
        'concertTitle': '2026 REMIND: 리센느',
        'posterImageUrl': 'poster/remind.gif',
        'startDate': '2026-10-10T19:00:00',
        'venueName': '올림픽공원 체조경기장',
        'sectionName': 'R석',
        'seatNo': 12,
        'seatCol': 24,
        'facePrice': 154000,
        'status': status,
        'createdAt': '2026-09-01T20:05:00',
      };

  /// 서버 주문 상세 응답. 실제 `ReservationDetailResponseDto` 모양이다. 주문
  /// 생성(201)과 진행 상태 조회가 같은 모양을 준다.
  Map<String, dynamic> detailJson({
    int id = 7,
    String status = 'PAID',
    String? tokenId,
    String? failureReason,
  }) => {
    'id': id,
    'orderId': 'reservation-$id',
    'concertId': 3,
    'concertTitle': '로이킴 콘서트',
    'posterImageUrl': 'poster/poster_main_roykim.jpg',
    'startDate': '2026-09-20T19:30:00',
    'venueName': '고척돔',
    'seatId': 1009,
    'sectionId': 1,
    'sectionName': 'A구역',
    'seatNo': 1,
    'seatCol': 9,
    'facePrice': 150000,
    'status': status,
    'tokenId': tokenId,
    'mintTxHash': tokenId == null ? null : '0xabc',
    'mintAttemptCount': tokenId == null && failureReason == null ? 0 : 1,
    'failureReason': failureReason,
    'createdAt': '2026-09-17T13:13:32',
    'updatedAt': '2026-09-17T13:13:32',
  };

  /// Spring `PagedModel` 로 감싼다.
  Map<String, dynamic> paged(List<Map<String, dynamic>> content) => {
    'content': content,
    'page': {
      'size': 100,
      'number': 0,
      'totalElements': content.length,
      'totalPages': 1,
    },
  };

  group('내 티켓 목록', () {
    // 예매 목록이 아니라 소유 기준 목록이다. 양도로 판 티켓이 빠지고 산 티켓이
    // 들어오는 쪽.
    test('티켓 조회 주소로 GET 하고 한 번에 다 받는다', () async {
      givenServer((_) => jsonResponse(paged([myTicketJson()])));

      await api.fetchMyTickets();

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/api/v1/tickets/me');
      // 상태로 거르지 않는다. 회수된 티켓도 회색 카드로 남겨야 한다.
      expect(request.query.containsKey('status'), isFalse);
      expect(request.query['size'], '100');
    });

    test('응답을 모델로 읽는다', () async {
      givenServer((_) => jsonResponse(paged([myTicketJson()])));

      final ticket = (await api.fetchMyTickets()).single;

      // 티켓 번호가 주 식별자다. 예매 번호는 취소할 때만 쓴다.
      expect(ticket.ticketId, 101);
      expect(ticket.reservationId, 1);
      expect(ticket.title, '2026 REMIND: 리센느');
      expect(ticket.status, TicketStatus.owned);
      expect(ticket.listed, isFalse);
      expect(ticket.acquiredBy, TicketAcquisition.booking);
      expect(ticket.acquiredAt, DateTime(2026, 9, 1, 20, 5));
      expect(ticket.facePrice, 154000);
      expect(ticket.startAt, DateTime(2026, 10, 10, 19));
    });

    // 이름이 직관과 반대라 뒤집혀 들어가기 쉬운 자리다.
    test('seatNo 가 열, seatCol 이 번으로 들어간다', () async {
      givenServer((_) => jsonResponse(paged([myTicketJson()])));

      final ticket = (await api.fetchMyTickets()).single;

      expect(ticket.seatRow, 12);
      expect(ticket.seatNumber, 24);
      expect(ticket.seatLabel, 'R석 12열 24번');
    });

    // 예매 목록에는 없던 값들이다. 이걸 보고 버튼을 미리 잠근다.
    test('양도 등록 중과 양도로 받은 티켓을 그대로 읽는다', () async {
      givenServer(
        (_) => jsonResponse(
          paged([
            myTicketJson(ticketId: 101, ticketStatus: 'LISTED', listed: true),
            myTicketJson(ticketId: 102, acquiredBy: 'TRANSFER'),
          ]),
        ),
      );

      final tickets = await api.fetchMyTickets();

      expect(tickets[0].isListed, isTrue);
      expect(tickets[0].isUsable, isFalse);
      expect(tickets[1].acquiredBy, TicketAcquisition.transfer);
      expect(tickets[1].isBooked, isFalse);
    });

    test('공연 날짜가 없어도 읽는다', () async {
      givenServer((_) => jsonResponse(paged([myTicketJson(startDate: null)])));

      expect((await api.fetchMyTickets()).single.startAt, isNull);
    });

    // 서버에 상태가 하나 늘어도 목록 전체가 깨지면 안 된다. 그 카드만 잠근다.
    test('모르는 상태는 알 수 없음으로 본다', () async {
      givenServer(
        (_) => jsonResponse(paged([myTicketJson(ticketStatus: 'BURNED')])),
      );

      final ticket = (await api.fetchMyTickets()).single;
      expect(ticket.status, TicketStatus.unknown);
      expect(ticket.isUsable, isFalse);
    });

    test('빈 목록은 정상 결과다', () async {
      givenServer((_) => jsonResponse(paged([])));

      expect(await api.fetchMyTickets(), isEmpty);
    });

    test('content 가 없는 응답이면 안내 문구로 바꾼다', () async {
      givenServer((_) => jsonResponse({'page': {}}));

      expect(() => api.fetchMyTickets(), throwsA(isA<ApiException>()));
    });

    test('연결이 끊기면 ApiException', () async {
      givenServer(
        (request) => throw DioException.connectionError(
          requestOptions: request.options,
          reason: 'offline',
        ),
      );

      await expectLater(
        api.fetchMyTickets(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            '인터넷 연결을 확인해주세요.',
          ),
        ),
      );
    });
  });

  group('예매 취소', () {
    test('예매 id 로 DELETE 한다', () async {
      givenServer((_) => jsonResponse(reservationJson(status: 'CANCELLED')));

      await api.cancelReservation(7);

      final request = adapter.requests.single;
      expect(request.method, 'DELETE');
      expect(request.path, '/api/v1/reservations/7');
    });

    // 취소 조건은 서버가 최종 판정한다. 화면이 미리 걸러도 시점 차이로 통과할 수 있다.
    test('서버가 거절하면 그 문구를 그대로 올린다', () async {
      givenServer(
        (_) => problemResponse(
          status: 409,
          errorMessage: '공연 시작 24시간 이내에는 취소할 수 없습니다.',
          exception: 'ReservationNotCancellableException',
        ),
      );

      await expectLater(
        api.cancelReservation(7),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 409)
              .having(
                (e) => e.exceptionName,
                'exceptionName',
                'ReservationNotCancellableException',
              ),
        ),
      );
    });
  });

  group('주문 생성', () {
    // 본문 필드 이름은 백엔드 CreateReservationRequestDto 와 같아야 한다.
    test('공연 번호와 좌석 번호를 담아 예매 목록 주소로 POST 한다', () async {
      givenServer((_) => jsonResponse(detailJson(), status: 201));

      await api.createReservation(concertId: 3, seatId: 1009);

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/api/v1/reservations');
      expect(request.jsonBody, {'concertId': 3, 'seatId': 1009});
    });

    // 주문 직후에는 아직 티켓이 안 나왔다. 발행이 끝난 것처럼 그리면 안 된다.
    test('응답을 읽고, 토큰이 없으면 발행 중이다', () async {
      givenServer((_) => jsonResponse(detailJson(), status: 201));

      final detail = await api.createReservation(concertId: 3, seatId: 1009);

      expect(detail.reservationId, 7);
      expect(detail.title, '로이킴 콘서트');
      expect(detail.seatLabel, 'A구역 1열 9번');
      expect(detail.facePrice, 150000);
      expect(detail.status, ReservationStatus.paid);
      expect(detail.issueStatus, TicketIssueStatus.issuing);
    });

    // 선점이 만료됐거나 남이 잡은 자리, 이미 산 공연은 서버가 막는다. 그 문구는
    // 화면이 그대로 보여주므로 잃어버리면 안 된다.
    test('서버가 거절하면 상태와 문구를 그대로 올린다', () async {
      givenServer(
        (_) => problemResponse(
          status: 409,
          errorMessage: '선점이 만료된 좌석입니다.',
          exception: 'SeatNotHeldException',
        ),
      );

      await expectLater(
        api.createReservation(concertId: 3, seatId: 1009),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 409)
              .having((e) => e.message, 'message', '선점이 만료된 좌석입니다.'),
        ),
      );
    });
  });

  group('주문 상세', () {
    test('예매 id 로 GET 한다', () async {
      givenServer((_) => jsonResponse(detailJson()));

      await api.fetchReservation(7);

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/api/v1/reservations/7');
    });

    test('토큰이 채워지면 발행 완료다', () async {
      givenServer((_) => jsonResponse(detailJson(tokenId: '42')));

      final detail = await api.fetchReservation(7);

      expect(detail.tokenId, '42');
      expect(detail.issueStatus, TicketIssueStatus.issued);
    });

    // 잔액 차감에 실패하면 서버가 주문을 되돌려 놓는다. 사유와 취소 상태가 함께 온다.
    test('실패 사유가 있으면 발행 실패다', () async {
      givenServer(
        (_) => jsonResponse(
          detailJson(
            status: 'CANCELLED',
            failureReason: 'insufficient balance',
          ),
        ),
      );

      final detail = await api.fetchReservation(7);

      expect(detail.issueStatus, TicketIssueStatus.failed);
    });

    // 사유 없이 취소만 돼 있어도 발행이 끝났다고 볼 수는 없다.
    test('사유가 없어도 주문이 취소됐으면 발행 실패로 본다', () async {
      givenServer((_) => jsonResponse(detailJson(status: 'CANCELLED')));

      expect(
        (await api.fetchReservation(7)).issueStatus,
        TicketIssueStatus.failed,
      );
    });

    test('남의 주문은 404 다', () async {
      givenServer(
        (_) => problemResponse(
          status: 404,
          errorMessage: '예매를 찾을 수 없습니다.',
          exception: 'ReservationNotFoundException',
        ),
      );

      await expectLater(
        api.fetchReservation(7),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
      );
    });
  });

  group('입장 QR 발급', () {
    /// 서버가 주는 문자열. `timo:entry:1:<티켓번호>.<만료>.<서명>` 꼴이지만 앱은
    /// 해석하지 않으므로 여기서도 그냥 문자열이다.
    const token = 'timo:entry:1:107.1789736400.AbCdEfGhIjKlMnOpQrStUv';

    /// 서버 입장 QR 응답. 실제 `EntryPassResponseDto` 모양이다.
    Map<String, dynamic> entryPassJson({int expiresInSeconds = 30}) => {
      'token': token,
      'expiresInSeconds': expiresInSeconds,
    };

    // 예매 번호가 아니라 티켓 번호다. 바꿔 넘기면 엉뚱한 티켓을 가리켜 404 가 난다.
    test('티켓 번호로 티켓 주소에 GET 한다', () async {
      givenServer((_) => jsonResponse(entryPassJson()));

      await api.issueEntryPass(107);

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/api/v1/tickets/107/entry-pass');
      expect(request.rawBody, isNull);
    });

    // 앱이 문자열 안을 해석하기 시작하면 서버가 형식을 바꿀 때마다 앱 배포까지
    // 묶인다. 남은 시간도 토큰이 아니라 따로 온 초 값으로 센다.
    test('문자열은 손대지 않고 그대로, 수명은 초 값으로 읽는다', () async {
      givenServer((_) => jsonResponse(entryPassJson(expiresInSeconds: 45)));

      final pass = await api.issueEntryPass(107);

      expect(pass.token, token);
      expect(pass.lifetime, const Duration(seconds: 45));
    });

    // 서버는 만료 시각이 아니라 남은 초만 준다. 어디서부터 셀지는 받은 쪽이 찍는다.
    test('받은 시각을 찍어 거기서부터 센다', () async {
      final received = DateTime(2026, 9, 14, 18, 30);
      givenServer((_) => jsonResponse(entryPassJson()), clock: () => received);

      final pass = await api.issueEntryPass(107);

      expect(pass.receivedAt, received);
      expect(
        pass.remaining(received.add(const Duration(seconds: 10))),
        const Duration(seconds: 20),
      );
    });

    // 남의 티켓도 403 이 아니라 404 다. 존재를 알리지 않는다(백엔드 규칙).
    test('없는 티켓·남의 티켓은 404 다', () async {
      givenServer(
        (_) => problemResponse(
          status: 404,
          errorMessage: '존재하지 않는 티켓입니다.',
          exception: 'TicketNotFoundException',
        ),
      );

      await expectLater(
        api.issueEntryPass(107),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
      );
    });

    // 사유(시간대·티켓 상태)는 서버만 안다. 화면이 그 문구를 그대로 보여주므로
    // 잃어버리면 안 된다.
    test('발급할 수 없는 티켓이면 409 와 서버 문구를 그대로 올린다', () async {
      givenServer(
        (_) => problemResponse(
          status: 409,
          errorMessage: '입장 QR 을 발급할 수 없는 티켓입니다.',
          exception: 'EntryPassNotIssuableException',
        ),
      );

      await expectLater(
        api.issueEntryPass(107),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 409)
              .having((e) => e.message, 'message', '입장 QR 을 발급할 수 없는 티켓입니다.'),
        ),
      );
    });

    test('JSON 객체가 아닌 응답이면 안내 문구로 바꾼다', () async {
      givenServer((_) => ResponseBody.fromString('<html>gateway</html>', 200));

      expect(() => api.issueEntryPass(107), throwsA(isA<ApiException>()));
    });
  });
}
