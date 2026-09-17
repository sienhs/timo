import '../models/gate_target.dart';
import '../models/verification_result.dart';

/// 스캔 화면이 서버에 요청하는 일.
///
/// 화면은 이 인터페이스만 안다. 지금은 [MockScanApi] 만 있다. 백엔드에 입장
/// 검증 API 가 생기면 같은 시그니처의 `HttpScanApi` 를 만들어 `app.dart` 에서
/// 갈아끼운다. 화면은 바뀌지 않는다.
///
/// 반환 규칙: 성공하면 결과를, 실패(네트워크·서버 오류)는 `ApiException` 으로
/// 던진다. **거절은 실패가 아니다** — 서버가 200 으로 [Rejected] 를 주는 것이
/// 계약이다. 4xx 로 거절을 표현하면 "티켓이 무효" 와 "요청이 잘못됨" 이 섞여
/// 화면이 상태 코드를 해석해야 한다.
abstract class ScanApi {
  /// 스캔한 QR 을 검증하고, 허용이면 티켓을 USED 로 바꾼다.
  ///
  /// [payload] 는 QR 에서 읽은 문자열 그대로다. 앱은 해석하지 않는다 — 형식·
  /// 서명·만료·소유자·상태 판단은 전부 서버가 한다.
  ///
  /// 요구사항: 정상 입장 1건은 3초 안에 끝나야 한다.
  Future<VerificationResult> verify({
    required String payload,
    required GateTarget target,
  });
}
