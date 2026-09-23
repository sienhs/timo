import '../models/entry_pass.dart';
import '../models/my_ticket.dart';
import '../models/reservation_detail.dart';

/// 예매(주문)·티켓 API. 내 티켓·결제·입장 QR 화면이 서버에 요청하는 일이다.
/// `HttpTicketApi` 가 실제 서버에 요청하고 테스트는 `MockTicketApi` 를 쓴다.
/// 결제 화면의 주문 생성·조회(`/api/v1/reservations`)와 입장 QR 발급
/// (`/api/v1/tickets`)도 여기 둔다. 실패는 `ApiException` 으로 던진다.
abstract class TicketApi {
  /// 지금 내가 가진 티켓 전부(`GET /api/v1/tickets/me`). 최근에 내 것이 된 순.
  /// 소유 기준이라 양도로 판 티켓은 빠지고 산 티켓은 들어온다. 예정·지난 필터가
  /// 서버에 없어 한 번에 다 받고, 회수된 티켓도 함께 온다.
  Future<List<MyTicket>> fetchMyTickets();

  /// 예매를 취소한다. 티켓은 회수되고 정가가 전액 포인트로 환원된다.
  /// 결제가 끝난 티켓만, 공연 시작 24시간 전까지다. 그 밖이면 서버가 409 로
  /// 거절한다. 화면은 [MyTicket.canCancel] 로 미리 걸러 버튼을 잠근다.
  Future<void> cancelReservation(int reservationId);

  /// 잡아 둔 자리로 주문을 확정한다. 결제 화면의 '결제하기' 다. 좌석 배정과
  /// 잔액 차감은 이 요청 안에서 끝나고 온체인 발행은 서버가 뒤에서 이어 가므로,
  /// 끝났는지는 [fetchReservation] 으로 다시 물어야 한다. 선점이 없거나
  /// 만료됐으면 409, 남의 선점이면 403, 이미 주문이 있거나 판매 중이 아니면 409.
  Future<ReservationDetail> createReservation({
    required int concertId,
    required int seatId,
  });

  /// 주문 상세와 발행 진행 상태. 완료 화면이 몇 초마다 물어 배지를 바꾼다.
  /// 남의 주문은 404 다.
  Future<ReservationDetail> fetchReservation(int reservationId);

  /// 입장 QR 한 장을 발급받는다. 예매 번호가 아니라 티켓 번호([MyTicket.ticketId])를
  /// 넘긴다. 서버에 아무것도 남기지 않아 몇 번을 불러도 된다. 남의 티켓·없는
  /// 티켓은 404. 발행 전·이미 입장·회수·양도 등록 중이거나 입장 시간대(공연 시작
  /// 2시간 전 ~ 6시간 뒤) 밖이면 409 — 시간대만 [MyTicket.canEnter] 로 미리 거른다.
  Future<EntryPass> issueEntryPass(int ticketId);
}
