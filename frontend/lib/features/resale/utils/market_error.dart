import '../../../core/network/api_exception.dart';
import '../constants.dart';

/// 운영 시간에 얽힌 거절을 서버가 던지는 예외의 클래스 이름. 백엔드의
/// `MarketClosedException`(닫혀 있어서) · `MarketOpenException`(열려 있어서) ·
/// `ListingNotOpenYetException`(매물이 아직 안 올라와서)과 같아야 한다.
const marketClosedExceptionName = 'MarketClosedException';
const marketOpenExceptionName = 'MarketOpenException';
const listingNotOpenYetExceptionName = 'ListingNotOpenYetException';

/// 온체인 체결이 실패했을 때 서버가 던지는 예외의 이름(`TransferFailedException`).
///
/// 서버는 revert 와 일시적 오류를 가리지 않고 이 하나로 묶으면서 "잠시 후 다시
/// 시도해 주세요" 라고 답한다. 그런데 가장 흔한 원인인 코인 부족은 다시
/// 시도해도 그대로라, 그 문구대로면 충전하러 가야 할 사람이 재시도만 한다.
/// 구매 화면이 미리 잔액을 보고 거르지만(`ListingPurchaseScreen`) 그 뒤에
/// 잔액이 바뀌었거나 남이 먼저 사 갔을 수 있어, 여기서도 원인을 열어 둔다.
const transferFailedExceptionName = 'TransferFailedException';

/// 마켓 요청 실패의 문구를 화면용으로 바꾼다. `HttpResaleApi` 가 모든 실패를
/// 여기로 한 번 통과시키므로, 스낵바든 목록의 오류 화면(`AsyncBoundary`)이든
/// 받는 쪽은 `message` 를 그대로 쓰면 된다.
///
/// 운영 시간 거절(409)은 서버 문구 뒤에 다음 여는 시각·마감 시각·노출 시각이
/// `(opensAt=2026-09-18T08:00:00)` 처럼 붙어 온다. 앱이 읽으라고 실은 값이라
/// 그대로 보이면 안 되므로 앱 문구로 바꾼다. 나머지 실패는 서버 문구를 그대로
/// 둔다 — 다른 도메인과 같다.
///
/// 클래스 이름으로 가르는 이유는 [ApiException.exceptionName] 주석과 같다.
/// `errorCode` 는 인증 응답에만 온다.
ApiException translateResaleError(ApiException e) {
  final message = switch (e.exceptionName) {
    marketClosedExceptionName => ResaleStrings.marketClosedError,
    marketOpenExceptionName => ResaleStrings.marketOpenError,
    listingNotOpenYetExceptionName => ResaleStrings.listingNotOpenYetError,
    transferFailedExceptionName => ResaleStrings.transferFailedError,
    _ => null,
  };
  if (message == null) return e;
  return ApiException(
    message,
    status: e.status,
    errorCode: e.errorCode,
    exceptionName: e.exceptionName,
    fieldErrors: e.fieldErrors,
  );
}
