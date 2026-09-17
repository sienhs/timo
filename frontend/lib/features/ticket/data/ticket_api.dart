import '../models/my_ticket.dart';
import '../models/reservation_detail.dart';

/// 예매(주문) API. 내 티켓 화면과 결제 화면이 서버에 요청하는 일이다.
///
/// 화면은 이 인터페이스만 안다. 앱에서는 [HttpTicketApi] 가 실제 서버에
/// 요청하고, 테스트와 화면 확인은 [MockTicketApi] 를 쓴다. 홈의 `HomeApi` 와
/// 같은 구조다.
///
/// 결제 화면의 주문 생성·진행 상태 조회도 여기 있다. 같은 주소
/// (`/api/v1/reservations`)를 쓰는 한 도메인이라 결제 쪽에 따로 API 를 두면
/// 같은 응답 모양을 두 번 읽게 된다.
///
/// 반환 규칙: 성공하면 결과를, 실패(네트워크·서버 오류)는 `ApiException` 으로
/// 던진다. 빈 목록은 실패가 아니라 "가진 티켓이 없다" 는 정상 결과다.
///
/// **양도 관련 메서드가 없는 이유**: 마켓 API 가 S15P21D206-297 에서 새로
/// 설계됐다. 매물 식별자가 `tokenId` 에서 `listingId` 로 바뀌고(온체인 공개값인
/// `tokenId` 를 내보내면 소유 이력이 역추적된다), 목록도 `GET /listings/me`
/// 하나로 합쳐졌으며, 응답에서 좌석 번호가 빠졌다. 양도 등록 진입점을 만들 때
/// 그 규약에 맞춰 새로 붙인다.
abstract class TicketApi {
  /// 내 티켓 전부. 최근 예매순.
  ///
  /// 예정·지난을 나누지 않고 한 번에 준다. 서버에 그 필터가 없어서, 나누려면
  /// 어차피 다 받아 공연 날짜로 갈라야 한다. 취소된 티켓도 함께 온다 —
  /// 목록에서 지우지 않고 결과를 보여줘야 하기 때문이다.
  Future<List<MyTicket>> fetchMyTickets();

  /// 예매를 취소한다. 티켓은 회수되고 정가가 전액 포인트로 환원된다.
  ///
  /// 결제가 끝난 티켓만, 공연 시작 24시간 전까지다. 그 밖이면 서버가 409 로
  /// 거절한다. 화면은 [MyTicket.canCancel] 로 미리 걸러 버튼을 잠근다.
  Future<void> cancelReservation(int reservationId);

  /// 잡아 둔 자리로 주문을 확정한다. 결제 화면의 '결제하기' 다.
  ///
  /// 좌석 배정과 잔액 차감은 이 요청 안에서 끝나고, 온체인 발행은 서버가
  /// 뒤에서 이어 간다. 그래서 응답이 왔어도 티켓은 아직 발행 중이고
  /// ([ReservationDetail.issueStatus]), 끝났는지는 [fetchReservation] 으로
  /// 다시 물어야 한다.
  ///
  /// 좌석 번호만으로는 어느 공연의 표인지 정해지지 않아(한 공연장에 여러
  /// 공연이 걸린다) 공연 번호를 함께 보낸다. 요청자가 이 자리를 유효하게
  /// 잡고 있어야 한다 — 선점이 없거나 만료됐으면 409, 남의 선점이면 403,
  /// 같은 공연에 이미 주문이 있거나 공연이 판매 중이 아니면 409 다.
  Future<ReservationDetail> createReservation({
    required int concertId,
    required int seatId,
  });

  /// 주문 상세와 발행 진행 상태. 완료 화면이 몇 초마다 물어 배지를 바꾼다.
  ///
  /// 남의 주문은 404 다(존재를 알리지 않는다).
  Future<ReservationDetail> fetchReservation(int reservationId);
}
