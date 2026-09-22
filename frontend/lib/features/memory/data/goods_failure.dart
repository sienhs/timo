import '../../../core/network/api_exception.dart';
import '../constants.dart';

/// 소장품 요청이 실패한 이유를 화면에 보여줄 한 줄로.
///
/// 이유는 예외 클래스 이름으로 가른다. 서버가 `BusinessException` 을
/// ProblemDetail 로 내보낼 때 실어 주는 값이고(`exception`), 상태 코드로는
/// 갈리지 않기 때문이다 — 409 하나에 "이미 만든 티켓"·"입장 전"·"지워진
/// 이미지" 셋이 들어 있다.
///
/// 모르는 이유는 서버 문구를 그대로 올린다. 서버만 아는 사정이 있을 수 있고,
/// 그 문구도 사용자에게 보여줄 한국어 한 줄이다. 서버 응답이 아닌 실패(파일
/// 오류 등)는 [fallback] 이다 — 무슨 일을 하다 실패했는지는 부른 쪽만 안다.
String goodsFailureMessage(
  Object error, {
  String fallback = ViewerText.confirmFailed,
}) {
  if (error is! ApiException) return fallback;

  return switch (error.exceptionName) {
    'GoodsAlreadyExistsException' => GoodsText.alreadyExists,
    'GoodsTicketNotOwnedException' => GoodsText.ticketNotOwned,
    'GoodsTicketNotUsedException' => GoodsText.ticketNotUsed,
    'GoodsImageDeletedException' => GoodsText.imageDeleted,
    'GoodsInvalidLayersException' => GoodsText.invalidLayers,
    _ => error.message,
  };
}
