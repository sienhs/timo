import 'listing.dart';
import 'wire_time.dart';

/// 양도 등록 화면에서 고를 수 있는 내 티켓 한 장.
///
/// **이 목록을 주는 서버 주소가 아직 없다.** 마켓 API 에는 등록(`POST /listings`)
/// 만 있고 "내가 등록할 수 있는 티켓" 을 주는 경로가 없으며, 티켓 도메인 자체가
/// 아직 컨트롤러 없이 엔티티만 있다. 그래서 [HttpResaleApi] 는 예매 목록
/// (`GET /api/v1/reservations`)에서 만들고, 등록 요청이 필요로 하는 [ticketId]
/// 자리에는 예매 번호가 들어간다 — 두 번호는 서로 다른 값이라 그 조합으로는
/// 등록이 서버에서 거절된다. 앱 기본값이 목 구현인 이유가 이것이다
/// ([ResaleApi] 주석).
///
/// 예매 응답에 `ticketId` 가 실리면 [fromReservationJson] 의 한 줄만 바뀐다.
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

  /// 예매 목록 응답(`ReservationSummaryResponseDto`) 한 건에서 만든다.
  factory ListableTicket.fromReservationJson(Map<String, dynamic> json) =>
      ListableTicket(
        // TODO(S15P21D206-307): 서버가 예매 응답에 ticketId 를 실어 주면 바꾼다.
        ticketId: (json['id'] as num).toInt(),
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
