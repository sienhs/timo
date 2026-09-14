import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/network/api_exception.dart';
import 'package:timo/features/ticket/data/http_ticket_api.dart';
import 'package:timo/features/ticket/models/ticket_status.dart';

import '../../core/network/fake_http_adapter.dart';

/// 예매 v0 스텁에 맞는 요청이 나가고 응답을 제대로 읽는지.
/// 서버 없이 [FakeHttpAdapter] 로 검사한다.
void main() {
  late FakeHttpAdapter adapter;
  late HttpTicketApi api;

  /// [handler] 가 돌려주는 응답으로 가짜 서버를 세운다.
  void givenServer(FutureOr<ResponseBody> Function(RecordedRequest) handler) {
    adapter = FakeHttpAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'http://fake.test'))
      ..httpClientAdapter = adapter;
    api = HttpTicketApi(dio: dio);
  }

  /// 서버 예매 목록 응답 한 건. 실제 `ReservationSummaryResponseDto` 모양이다.
  Map<String, dynamic> reservationJson({
    int id = 1,
    String status = 'MINTED',
    String? startDate = '2026-10-10T19:00:00',
  }) => {
    'id': id,
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
    'status': status,
    'createdAt': '2026-09-01T20:05:00',
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
    test('예매 목록 주소로 GET 하고 한 번에 다 받는다', () async {
      givenServer((_) => jsonResponse(paged([reservationJson()])));

      await api.fetchMyTickets();

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/api/v0/reservations');
      // 상태로 거르지 않는다. 발행 중·실패·취소된 티켓도 카드로 그려야 한다.
      expect(request.query.containsKey('status'), isFalse);
      expect(request.query['size'], '100');
    });

    test('응답을 모델로 읽는다', () async {
      givenServer((_) => jsonResponse(paged([reservationJson()])));

      final tickets = await api.fetchMyTickets();

      final ticket = tickets.single;
      expect(ticket.reservationId, 1);
      expect(ticket.title, '2026 REMIND: 리센느');
      expect(ticket.status, TicketStatus.minted);
      expect(ticket.facePrice, 154000);
      expect(ticket.startAt, DateTime(2026, 10, 10, 19));
    });

    // 이름이 직관과 반대라 뒤집혀 들어가기 쉬운 자리다.
    test('seatNo 가 열, seatCol 이 번으로 들어간다', () async {
      givenServer((_) => jsonResponse(paged([reservationJson()])));

      final ticket = (await api.fetchMyTickets()).single;

      expect(ticket.seatRow, 12);
      expect(ticket.seatNumber, 24);
      expect(ticket.seatLabel, 'R석 12열 24번');
    });

    test('공연 날짜가 없어도 읽는다', () async {
      givenServer(
        (_) => jsonResponse(paged([reservationJson(startDate: null)])),
      );

      expect((await api.fetchMyTickets()).single.startAt, isNull);
    });

    // 서버에 상태가 하나 늘어도 목록 전체가 깨지면 안 된다.
    test('모르는 상태는 발행 중으로 본다', () async {
      givenServer(
        (_) => jsonResponse(paged([reservationJson(status: 'TRANSFERRED')])),
      );

      expect(
        (await api.fetchMyTickets()).single.status,
        TicketStatus.pendingMint,
      );
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
      expect(request.path, '/api/v0/reservations/7');
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
}
