import 'listing.dart';
import 'wire_time.dart';

/// 양도 등록 화면에서 고를 수 있는 내 티켓 한 장. 이 목록만 주는 서버 주소는
/// 없어 [HttpResaleApi] 가 내 티켓 목록(`GET /api/v1/tickets/me`)에서 골라
/// 만든다. 등록 요청이 받는 [ticketId] 는 그 응답의 `ticketId` 다 — 예매 번호
/// (`reservationId`)와 다른 값이라 바꿔 넣으면 서버가 거절한다.
class ListableTicket {
  const ListableTicket({
    required this.ticketId,
    required this.concertTitle,
    required this.venueName,
    required this.sectionName,
    required this.seatRow,
    required this.seatNumber,
    required this.facePrice,
    this.posterImageUrl,
    this.startAt,
  });

  /// 내 티켓 목록 응답(`MyTicketSummaryResponseDto`) 한 건에서 만든다. 팔 수
  /// 있는지는 [HttpResaleApi] 가 먼저 거르고, 여기서는 카드에 그릴 값만 읽는다.
  factory ListableTicket.fromMyTicketJson(Map<String, dynamic> json) =>
      ListableTicket(
        ticketId: (json['ticketId'] as num).toInt(),
        concertTitle: json['concertTitle'] as String,
        venueName: json['venueName'] as String,
        // 서버 필드 이름이 직관과 반대다. `seatNo` 가 구역 안의 행(열) 번호,
        // `seatCol` 이 그 행 안의 자리 번호다(백엔드 Seat 엔티티 주석).
        sectionName: json['sectionName'] as String,
        seatRow: (json['seatNo'] as num).toInt(),
        seatNumber: (json['seatCol'] as num).toInt(),
        facePrice: (json['facePrice'] as num).toInt(),
        posterImageUrl: json['posterImageUrl'] as String?,
        startAt: dateTimeOrNull(json['startDate']),
      );

  /// 등록 요청(`POST /listings`)이 받는 티켓 번호.
  final int ticketId;

  final String concertTitle;
  final String venueName;

  /// 내 티켓이라 좌석이 늘 있다. 매물([Listing])과 달리 선택값이 아니다.
  final String sectionName;
  final int seatRow;
  final int seatNumber;

  /// 카드에 찍는 좌석. (예: `R구역 12열 24번`)
  String get seatLabel => formatSeatLabel(sectionName, seatRow, seatNumber);

  /// 예매 시점의 정가(원). 등록가의 상한이다.
  final int facePrice;

  final String? posterImageUrl;
  final DateTime? startAt;
}
