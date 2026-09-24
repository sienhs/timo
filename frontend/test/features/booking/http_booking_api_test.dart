import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/network/api_exception.dart';
import 'package:timo/core/network/server_errors.dart';
import 'package:timo/features/booking/data/http_booking_api.dart';
import 'package:timo/features/booking/models/seat.dart';

import '../../core/network/fake_http_adapter.dart';

/// 좌석 v1 API 에 맞는 요청이 나가고 응답을 제대로 읽는지.
/// 서버 없이 [FakeHttpAdapter] 로 검사한다.
void main() {
  late FakeHttpAdapter adapter;
  late HttpBookingApi api;

  void givenServer(FutureOr<ResponseBody> Function(RecordedRequest) handler) {
    adapter = FakeHttpAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'http://fake.test'))
      ..httpClientAdapter = adapter;
    api = HttpBookingApi(dio: dio);
  }

  /// 구역 목록 응답. 실제 `SectionListResponseDto` 모양이다.
  Map<String, dynamic> sectionsJson() => {
    'venueId': 1,
    'venueName': '고척돔',
    'totalSeatCount': 400,
    'totalAvailableCount': 300,
    'sections': [
      {
        'id': 1,
        'name': '1층 A블록',
        'grade': 'COMMON',
        'price': 150000,
        'seatCount': 200,
        'availableCount': 199,
        'rowCount': 10,
        'seatPerRow': 20,
      },
      {
        'id': 2,
        'name': '1층 B블록',
        'grade': 'COMMON',
        'price': 150000,
        'seatCount': 200,
        'availableCount': 0,
        'rowCount': 10,
        'seatPerRow': 20,
      },
    ],
  };

  /// 좌석 목록 응답. 2열 3번 격자에서 2열 2번이 통로로 빠진 배치다.
  /// (백엔드 API 명세의 예시와 같은 모양)
  Map<String, dynamic> seatsJson() => {
    'sectionId': 1,
    'sectionName': '1층 A블록',
    'grade': 'COMMON',
    'price': 150000,
    'seatCount': 5,
    'availableCount': 3,
    'rowCount': 2,
    'seatPerRow': 3,
    'seats': [
      {'id': 1, 'seatNo': 1, 'seatCol': 1, 'status': 'AVAILABLE'},
      {'id': 2, 'seatNo': 1, 'seatCol': 2, 'status': 'HELD'},
      {'id': 3, 'seatNo': 1, 'seatCol': 3, 'status': 'SOLD'},
      {'id': 4, 'seatNo': 2, 'seatCol': 1, 'status': 'AVAILABLE'},
      {'id': 6, 'seatNo': 2, 'seatCol': 3, 'status': 'AVAILABLE'},
    ],
  };

  group('구역 목록', () {
    test('공연 번호를 실어 요청하고 구역을 읽는다', () async {
      givenServer((_) => jsonResponse(sectionsJson()));

      final zones = await api.fetchZones(7);

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/api/v1/sections');
      // 공연장이 아니라 공연으로 묻는다. 잔여석이 공연마다 다르기 때문이다.
      expect(request.query['concertId'], '7');

      expect(zones, hasLength(2));
      expect(zones.first.id, 1);
      expect(zones.first.name, '1층 A블록');
      expect(zones.first.price, 150000);
      expect(zones.first.availableCount, 199);
      expect(zones.first.isSoldOut, isFalse);
      expect(zones.last.isSoldOut, isTrue);
    });

    test('구역 이름으로 좌석 이름을 만든다', () async {
      givenServer((_) => jsonResponse(sectionsJson()));

      final zone = (await api.fetchZones(1)).first;
      const seat = Seat(id: 1, row: 9, number: 6, status: SeatStatus.available);

      expect(zone.seatLabel(seat), '1층 A블록 9열 6번');
    });
  });

  group('좌석 목록', () {
    test('공연과 구역을 함께 실어 요청한다', () async {
      givenServer((_) => jsonResponse(seatsJson()));

      await api.fetchSeats(concertId: 7, zoneId: 3);

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/api/v1/seats');
      expect(request.query['concertId'], '7');
      expect(request.query['sectionId'], '3');
    });

    test('좌석을 제 열·번호 자리에 꽂고 빠진 자리는 빈 칸으로 둔다', () async {
      givenServer((_) => jsonResponse(seatsJson()));

      final zoneSeats = await api.fetchSeats(concertId: 1, zoneId: 1);

      expect(zoneSeats.zoneName, '1층 A블록');
      expect(zoneSeats.rows, hasLength(2));
      expect(zoneSeats.rows.first, hasLength(3));

      // 통로로 빠진 2열 2번. 목록 순서대로 줄 세웠다면 여기에 2열 3번이 왔다.
      expect(zoneSeats.rows[1][1], isNull);
      expect(zoneSeats.rows[1][2]?.id, 6);
    });

    test('상태 세 가지를 읽는다', () async {
      givenServer((_) => jsonResponse(seatsJson()));

      final rows = (await api.fetchSeats(concertId: 1, zoneId: 1)).rows;

      expect(rows[0][0]?.status, SeatStatus.available);
      expect(rows[0][1]?.status, SeatStatus.held);
      expect(rows[0][2]?.status, SeatStatus.sold);
    });

    test('모르는 상태는 고를 수 없는 자리로 본다', () async {
      givenServer(
        (_) => jsonResponse({
          ...seatsJson(),
          'seats': [
            {'id': 1, 'seatNo': 1, 'seatCol': 1, 'status': 'LOCKED'},
          ],
        }),
      );

      final rows = (await api.fetchSeats(concertId: 1, zoneId: 1)).rows;

      expect(rows[0][0]?.status, SeatStatus.sold);
      expect(rows[0][0]?.isSelectable, isFalse);
    });
  });

  group('좌석 선점', () {
    test('좌석 번호는 주소에, 공연 번호는 조건에 실어 보낸다', () async {
      givenServer(
        (_) => jsonResponse({
          'seatId': 1005,
          'sectionId': 1,
          'sectionName': '1층 A블록',
          'seatNo': 1,
          'seatCol': 5,
          'status': 'HELD',
          'price': 150000,
          'expiresAt': '2026-09-14T19:59:22',
          'releasedSeatId': 1001,
        }),
      );

      final hold = await api.holdSeat(concertId: 7, seatId: 1005);

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/api/v1/seats/1005/hold');
      expect(request.query['concertId'], '7');

      expect(hold.seatId, 1005);
      expect(hold.expiresAt, DateTime(2026, 9, 14, 19, 59, 22));
      // 새 자리를 잡으면 앞서 잡은 자리가 풀린다. 배치도를 되돌리려면
      // 어디가 풀렸는지 알아야 한다.
      expect(hold.releasedSeatId, 1001);
    });

    test('잡은 자리의 값을 읽는다. 결제 화면이 보여 줄 금액이다', () async {
      // 배치도에서 받은 구역 가격을 들고 다니지 않고 여기서 받는다. 구역을
      // 바꿔 다시 잡았을 때 어긋나지 않게 하려는 것이다.
      givenServer(
        (_) => jsonResponse({
          'seatId': 1005,
          'sectionId': 1,
          'sectionName': '1층 A블록',
          'seatNo': 1,
          'seatCol': 5,
          'status': 'HELD',
          'price': 150000,
          'expiresAt': '2026-09-14T19:59:22',
          'releasedSeatId': null,
        }),
      );

      final hold = await api.holdSeat(concertId: 7, seatId: 1005);

      expect(hold.price, 150000);
    });

    test('남은 시간은 기기 시계가 서버와 어긋나도 5분에서 시작한다', () async {
      givenServer(
        (_) => jsonResponse({
          'seatId': 1005,
          'sectionId': 1,
          'sectionName': '1층 A블록',
          'seatNo': 1,
          'seatCol': 5,
          'status': 'HELD',
          'price': 150000,
          // 서버는 시간대 없는 시각을 준다. 기기 타임존이 서버와 다르면 이 값에서
          // 지금을 빼는 방식으로는 엉뚱한 시간이 나온다.
          'expiresAt': '2000-01-01T00:00:00',
          'releasedSeatId': null,
        }),
      );

      final hold = await api.holdSeat(concertId: 1, seatId: 1005);

      expect(hold.remainingFrom(hold.heldAt), const Duration(minutes: 5));
      expect(
        hold.remainingFrom(hold.heldAt.add(const Duration(minutes: 2))),
        const Duration(minutes: 3),
      );
      // 다 지난 뒤에는 0 이라 결제 버튼이 잠긴다.
      expect(
        hold.remainingFrom(hold.heldAt.add(const Duration(minutes: 6))),
        Duration.zero,
      );
    });

    test('남이 먼저 가져갔으면 서버 문구를 그대로 던진다', () async {
      givenServer(
        (_) => problemResponse(
          status: 409,
          errorMessage: '이미 선택된 좌석입니다. (seatId=1005)',
          exception: 'SeatNotHoldableException',
        ),
      );

      await expectLater(
        api.holdSeat(concertId: 1, seatId: 1005),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 409)
              .having((e) => e.message, 'message', contains('이미 선택된 좌석')),
        ),
      );
    });

    test('로그인 상태가 아니면 401 로 온다', () async {
      givenServer(
        (_) => problemResponse(
          status: 401,
          errorMessage: '인증 정보가 올바르지 않습니다. 다시 로그인해 주세요.',
          exception: 'TokenInvalidException',
        ),
      );

      await expectLater(
        api.holdSeat(concertId: 1, seatId: 1),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
      );
    });
  });

  group('선점 취소', () {
    test('같은 주소로 DELETE 한다', () async {
      givenServer(
        (_) => jsonResponse({
          'seatId': 1005,
          'sectionId': 1,
          'sectionName': '1층 A블록',
          'seatNo': 1,
          'seatCol': 5,
          'status': 'AVAILABLE',
        }),
      );

      await api.cancelHold(concertId: 7, seatId: 1005);

      final request = adapter.requests.single;
      expect(request.method, 'DELETE');
      expect(request.path, '/api/v1/seats/1005/hold');
      expect(request.query['concertId'], '7');
    });

    test('남의 자리를 풀려고 하면 403 으로 온다', () async {
      givenServer(
        (_) => problemResponse(
          status: 403,
          errorMessage: '본인이 선점한 좌석이 아닙니다. (seatId=5)',
          exception: 'SeatHoldNotOwnedException',
        ),
      );

      await expectLater(
        api.cancelHold(concertId: 1, seatId: 5),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
      );
    });
  });

  group('보안문자', () {
    test('POST 로 받고 base64 그림을 바이트로 푼다', () async {
      givenServer(
        (_) => jsonResponse({
          'captchaKey': 'key-1',
          'image': base64Encode([1, 2, 3]),
          'imageType': 'image/jpeg',
          'expiresIn': 120,
        }),
      );

      final challenge = await api.issueCaptcha();

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/api/v1/captcha');
      expect(challenge.captchaKey, 'key-1');
      expect(challenge.image, [1, 2, 3]);
      expect(challenge.expiresIn, const Duration(minutes: 2));
    });

    test('그림이 base64 가 아니면 화면용 문구로 바꾼다', () async {
      givenServer(
        (_) => jsonResponse({
          'captchaKey': 'key-1',
          'image': '###',
          'imageType': 'image/jpeg',
          'expiresIn': 120,
        }),
      );

      await expectLater(
        api.issueCaptcha(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('서버 응답을 읽을 수 없어요'),
          ),
        ),
      );
    });

    test('확인은 공연·키·입력값을 본문에 싣는다', () async {
      givenServer((_) => jsonResponse({'expiresIn': 300}));

      await api.verifyCaptcha(concertId: 7, captchaKey: 'key-1', value: 'AB12');

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/api/v1/captcha/verify');
      expect(request.jsonBody, {
        'concertId': 7,
        'captchaKey': 'key-1',
        'value': 'AB12',
      });
    });

    test('오답이면 서버 문구를 그대로 던진다', () async {
      givenServer(
        (_) => problemResponse(
          status: 400,
          errorMessage: '보안문자가 일치하지 않습니다.',
          exception: 'CaptchaMismatchException',
        ),
      );

      await expectLater(
        api.verifyCaptcha(concertId: 7, captchaKey: 'key-1', value: 'x'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 400)
              .having((e) => e.message, 'message', '보안문자가 일치하지 않습니다.'),
        ),
      );
    });

    test('통과 기록 없이 좌석을 받으면 예외 이름으로 가려낼 수 있다', () async {
      givenServer(
        (_) => problemResponse(
          status: 403,
          errorMessage: '보안문자 확인이 필요합니다.',
          exception: BookingServerErrors.captchaRequired,
        ),
      );

      await expectLater(
        api.fetchSeats(concertId: 7, zoneId: 1),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 403)
              .having(
                (e) => e.exceptionName,
                'exceptionName',
                BookingServerErrors.captchaRequired,
              ),
        ),
      );
    });
  });

  test('JSON 이 아닌 응답은 화면용 문구로 바꾼다', () async {
    givenServer(
      (_) => ResponseBody.fromString('<html>gateway</html>', 200, headers: {}),
    );

    await expectLater(
      api.fetchZones(1),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('서버 응답을 읽을 수 없어요'),
        ),
      ),
    );
  });
}
