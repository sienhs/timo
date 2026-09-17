import '../../../core/network/api_exception.dart';
import '../constants.dart';
import '../models/gate_target.dart';
import '../models/verification_result.dart';
import 'scan_api.dart';

/// 서버 없이 스캔 흐름을 끝까지 돌려 보는 가짜 구현.
///
/// 팬 앱이 지금 만드는 QR(`timo:entry:<예매ID>:<발급초>:<nonce>`)을 읽어 서버가
/// 할 판정을 흉내 낸다. 판정 규칙은 예매 ID 로 갈라, 실기기에서 팬 앱 QR 을
/// 직접 대 보며 결과 화면을 전부 볼 수 있게 했다:
///
/// | 조건 | 결과 |
/// |---|---|
/// | 형식이 다름 | [RejectReason.invalid] |
/// | 발급 30초 지남 | [RejectReason.expired] |
/// | 이 세션에서 이미 통과한 예매 | [RejectReason.alreadyUsed] |
/// | 예매 ID 가 7 의 배수 | [RejectReason.revoked] |
/// | 예매 ID 가 11 의 배수 | [RejectReason.wrongConcert] |
/// | 그 외 | [Admitted] |
///
/// [failing] 이면 매번 서버 장애를 흉내 낸다(확인 실패 화면용).
class MockScanApi implements ScanApi {
  MockScanApi({this.failing = false, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final bool failing;
  final DateTime Function() _clock;

  /// 이 세션에서 입장 처리한 예매. 서버의 USED 전이를 흉내 낸다.
  final Set<int> _admitted = {};

  static const revokedDivisor = 7;
  static const wrongConcertDivisor = 11;

  /// 로그인·공연 선택이 붙기 전까지 헤더에 보일 대상.
  static const target = GateTarget(
    concertId: 1,
    concertTitle: '2026 ㅇㅇㅇ 콘서트',
  );

  @override
  Future<VerificationResult> verify({
    required String payload,
    required GateTarget target,
  }) async {
    await Future<void>.delayed(ScanMetrics.mockLatency);
    if (failing) {
      throw const ApiException('서버 응답이 늦어지고 있어요. 다시 스캔해주세요.');
    }

    final parsed = _parse(payload);
    if (parsed == null) return const Rejected(reason: RejectReason.invalid);

    final (reservationId, issuedAt) = parsed;

    if (_clock().difference(issuedAt) > EntryPayload.lifetime) {
      return const Rejected(reason: RejectReason.expired);
    }
    if (_admitted.contains(reservationId)) {
      return const Rejected(reason: RejectReason.alreadyUsed);
    }
    if (reservationId % revokedDivisor == 0) {
      return const Rejected(reason: RejectReason.revoked);
    }
    if (reservationId % wrongConcertDivisor == 0) {
      return const Rejected(reason: RejectReason.wrongConcert);
    }

    _admitted.add(reservationId);
    return const Admitted();
  }

  /// 팬 앱 형식이면 (예매ID, 발급시각), 아니면 null.
  static (int, DateTime)? _parse(String payload) {
    if (!payload.startsWith(EntryPayload.prefix)) return null;
    final parts = payload.substring(EntryPayload.prefix.length).split(':');
    if (parts.length != 3) return null;
    final reservationId = int.tryParse(parts[0]);
    final seconds = int.tryParse(parts[1]);
    if (reservationId == null || seconds == null) return null;
    return (reservationId, DateTime.fromMillisecondsSinceEpoch(seconds * 1000));
  }
}
