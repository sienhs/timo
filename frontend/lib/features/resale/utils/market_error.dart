import '../../../core/network/api_exception.dart';
import '../constants.dart';

/// 운영 시간에 얽힌 거절을 서버가 던지는 예외의 클래스 이름. 백엔드의
/// `MarketClosedException`(닫혀 있어서) · `MarketOpenException`(열려 있어서) ·
/// `ListingNotOpenYetException`(매물이 아직 안 올라와서)과 같아야 한다.
const marketClosedExceptionName = 'MarketClosedException';
const marketOpenExceptionName = 'MarketOpenException';
const listingNotOpenYetExceptionName = 'ListingNotOpenYetException';

/// 온체인 체결이 실패했을 때 서버가 던지는 예외의 이름(`TransferFailedException`).
/// 서버 문구는 재시도만 권하지만 흔한 원인인 코인 부족은 재시도해도 그대로라
/// 앱 문구로 바꾼다.
const transferFailedExceptionName = 'TransferFailedException';

/// 마켓 요청 실패의 문구를 화면용으로 바꾼다. `HttpResaleApi` 가 모든 실패를
/// 여기로 통과시킨다. 운영 시간 거절(409)은 서버 문구 뒤에 `(opensAt=...)` 같은
/// 값이 붙어 와 앱 문구로 바꾸고, 나머지는 서버 문구 그대로 둔다. 클래스
/// 이름으로 가르는 이유는 [ApiException.exceptionName] 주석과 같다.
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
