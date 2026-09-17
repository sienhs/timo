import 'package:flutter_test/flutter_test.dart';
import 'package:timo_gate/core/network/api_exception.dart';
import 'package:timo_gate/features/scan/data/mock_scan_api.dart';
import 'package:timo_gate/features/scan/models/verification_result.dart';

/// 목 판정 규칙이 문서(클래스 주석의 표)와 같은지 고정한다. 실기기에서 결과
/// 화면을 볼 때 이 규칙에 기대므로, 규칙이 바뀌면 표와 함께 바꿔야 한다.
void main() {
  final now = DateTime(2026, 9, 20, 19);
  final target = MockScanApi.target;

  String payload(int reservationId, {Duration age = Duration.zero}) {
    final seconds = now.subtract(age).millisecondsSinceEpoch ~/ 1000;
    return 'timo:entry:$reservationId:$seconds:abcd';
  }

  MockScanApi api() => MockScanApi(clock: () => now);

  test('팬 앱 형식의 새 QR 은 입장', () async {
    final result = await api().verify(payload: payload(1), target: target);
    expect(result, isA<Admitted>());
  });

  test('같은 예매를 두 번 대면 두 번째는 이미 입장', () async {
    final scanner = api();
    await scanner.verify(payload: payload(1), target: target);
    final result = await scanner.verify(payload: payload(1), target: target);
    expect(result, isA<Rejected>());
    expect((result as Rejected).reason, RejectReason.alreadyUsed);
  });

  test('발급 30초가 지난 QR 은 만료', () async {
    final result = await api().verify(
      payload: payload(1, age: const Duration(seconds: 31)),
      target: target,
    );
    expect((result as Rejected).reason, RejectReason.expired);
  });

  test('우리 형식이 아니면 유효하지 않음', () async {
    final result = await api().verify(
      payload: 'https://example.com',
      target: target,
    );
    expect((result as Rejected).reason, RejectReason.invalid);
  });

  test('예매 ID 가 7 의 배수면 회수, 11 의 배수면 다른 공연', () async {
    final scanner = api();
    final revoked = await scanner.verify(payload: payload(14), target: target);
    final wrong = await scanner.verify(payload: payload(22), target: target);
    expect((revoked as Rejected).reason, RejectReason.revoked);
    expect((wrong as Rejected).reason, RejectReason.wrongConcert);
  });

  test('failing 이면 ApiException', () {
    expect(
      MockScanApi(failing: true).verify(payload: payload(1), target: target),
      throwsA(isA<ApiException>()),
    );
  });

  test('모르는 서버 코드는 unknown 으로 받는다', () {
    expect(RejectReason.fromCode('SOMETHING_NEW'), RejectReason.unknown);
    expect(RejectReason.fromCode('EXPIRED'), RejectReason.expired);
  });
}
