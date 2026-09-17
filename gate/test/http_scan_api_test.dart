import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo_gate/core/network/api_exception.dart';
import 'package:timo_gate/features/scan/data/http_scan_api.dart';
import 'package:timo_gate/features/scan/models/gate_target.dart';
import 'package:timo_gate/features/scan/models/verification_result.dart';

import 'core/network/fake_http_adapter.dart';

/// 실제 서버 구현이 백엔드 검표 규약대로 요청하고 응답을 읽는지, 가짜 서버로 검사한다.
///
/// 주소·본문 키는 백엔드 GateEntryApi 와 GateEntryVerifyRequestDto 에서 그대로
/// 가져왔다. 백엔드가 바뀌면 이 테스트를 같이 고쳐야 한다.
void main() {
  const target = GateTarget(concertId: 42, concertTitle: '테스트 공연');
  const payload = 'timo:entry:1:1758000000:abcd';

  late FakeHttpAdapter adapter;

  HttpScanApi build(FutureOr<ResponseBody> Function(RecordedRequest) respond) {
    adapter = FakeHttpAdapter(respond);
    final dio = Dio(BaseOptions(baseUrl: 'http://fake.test'))
      ..httpClientAdapter = adapter;
    return HttpScanApi(dio: dio);
  }

  test('QR 원문과 공연 ID 를 POST /entries/verify 로 보낸다', () async {
    final api = build((_) => jsonResponse({'admitted': true}));

    await api.verify(payload: payload, target: target);

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, HttpScanApi.verifyPath);
    expect(request.jsonBody, {'qr': payload, 'concertId': 42});
  });

  test('admitted 가 참이면 입장', () async {
    final api = build((_) => jsonResponse({'admitted': true}));

    final result = await api.verify(payload: payload, target: target);

    expect(result, isA<Admitted>());
  });

  test('거절은 200 으로 오고 reasonCode 를 사유로 바꾼다', () async {
    final api = build(
      (_) => jsonResponse({'admitted': false, 'reasonCode': 'ALREADY_USED'}),
    );

    final result = await api.verify(payload: payload, target: target);

    expect(result, isA<Rejected>());
    expect((result as Rejected).reason, RejectReason.alreadyUsed);
  });

  test('모르는 거절 코드는 unknown 으로 받아 앱이 죽지 않는다', () async {
    final api = build(
      (_) => jsonResponse({'admitted': false, 'reasonCode': 'BRAND_NEW'}),
    );

    final result = await api.verify(payload: payload, target: target);

    expect((result as Rejected).reason, RejectReason.unknown);
  });

  test('4xx·5xx 는 판정이 아니라 실패다. 관리자가 아닌 403 도 마찬가지', () async {
    final api = build(
      (_) => problemResponse(
        status: 403,
        errorMessage: '접근 권한이 없습니다.',
        exception: 'AccessDeniedException',
      ),
    );

    await expectLater(
      api.verify(payload: payload, target: target),
      throwsA(
        isA<ApiException>()
            .having((e) => e.status, 'status', 403)
            .having((e) => e.message, 'message', '접근 권한이 없습니다.'),
      ),
    );
  });

  test('서버에 닿지 못하면 안내 문구를 담은 예외가 나간다', () async {
    final api = build(
      (request) => throw DioException(
        type: DioExceptionType.connectionError,
        requestOptions: request.options,
      ),
    );

    await expectLater(
      api.verify(payload: payload, target: target),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          '인터넷 연결을 확인해주세요.',
        ),
      ),
    );
  });

  test('JSON 이 아니거나 admitted 가 없는 응답은 화면용 예외로 바꾼다', () async {
    final html = build(
      (_) => ResponseBody.fromString(
        '<html>Service Unavailable</html>',
        200,
        headers: {
          Headers.contentTypeHeader: ['text/html'],
        },
      ),
    );
    await expectLater(
      html.verify(payload: payload, target: target),
      throwsA(isA<ApiException>()),
    );

    final missing = build((_) => jsonResponse({'reasonCode': 'EXPIRED'}));
    await expectLater(
      missing.verify(payload: payload, target: target),
      throwsA(isA<ApiException>()),
    );
  });
}
