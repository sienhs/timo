import '../constants.dart';
import 'ticket_status.dart';

/// 내가 가진 티켓 한 장. 서버 예매 목록 응답
/// (`ReservationSummaryResponseDto`) 한 건이다.
///
/// 예정 공연과 지난 공연이 같은 모델이다. 서버가 그 둘을 나눠 주지 않고
/// ([isPast] 로 화면이 가른다) 카드에 들어가는 값도 같아서, 나누면 똑같은
/// 필드를 가진 클래스가 둘 생길 뿐이다.
class MyTicket {
  const MyTicket({
    required this.reservationId,
    required this.ticketId,
    required this.concertId,
    required this.title,
    required this.venueName,
    required this.sectionName,
    required this.seatRow,
    required this.seatNumber,
    required this.facePrice,
    required this.status,
    required this.bookedAt,
    this.posterImageUrl,
    this.startAt,
  });

  factory MyTicket.fromJson(Map<String, dynamic> json) => MyTicket(
    reservationId: (json['id'] as num).toInt(),
    ticketId: (json['ticketId'] as num).toInt(),
    concertId: (json['concertId'] as num).toInt(),
    title: json['concertTitle'] as String,
    venueName: json['venueName'] as String,
    sectionName: json['sectionName'] as String,
    // 서버 필드 이름이 직관과 반대다. `seatNo` 가 구역 안의 **행(열) 번호**,
    // `seatCol` 이 그 행 안의 **자리 번호**다(백엔드 Seat 엔티티 주석).
    // 읽는 자리에서 한 번 제 이름으로 바꿔 담아, 화면마다 헷갈릴 일을 없앤다.
    seatRow: (json['seatNo'] as num).toInt(),
    seatNumber: (json['seatCol'] as num).toInt(),
    facePrice: (json['facePrice'] as num).toInt(),
    status: TicketStatus.fromWire(json['status']),
    bookedAt: DateTime.parse(json['createdAt'] as String),
    posterImageUrl: json['posterImageUrl'] as String?,
    startAt: _dateTimeOrNull(json['startDate']),
  );

  /// 예매 id. 취소할 때 쓴다.
  final int reservationId;

  /// 이 예매로 발행된 티켓의 id. 양도 등록이 받는 번호다 — [reservationId] 와
  /// **다른 값**이라 바꿔 쓰면 서버가 거절한다(백엔드
  /// `ReservationSummaryResponseDto` 주석). 주문과 같은 트랜잭션에서 만들어져
  /// 발행 전에도 늘 있다.
  final int ticketId;

  final int concertId;
  final String title;
  final String venueName;

  /// 구역 이름. (예: `R석`)
  final String sectionName;

  /// 구역 안에서의 행 번호. 화면에는 `열` 로 찍는다.
  final int seatRow;

  /// 행 안에서의 자리 번호. 화면에는 `번` 으로 찍는다.
  final int seatNumber;

  /// 정가(원). 양도 등록가의 상한이다.
  final int facePrice;

  final TicketStatus status;

  /// 예매한 시각.
  final DateTime bookedAt;

  /// 포스터 주소. 포스터가 없는 공연이면 null.
  final String? posterImageUrl;

  /// 공연 시작 일시. 아직 정해지지 않았으면 null.
  final DateTime? startAt;

  /// 카드에 찍는 좌석. (예: `R석 12열 24번`)
  String get seatLabel => '$sectionName $seatRow열 $seatNumber번';

  /// 이미 끝난 공연인가.
  ///
  /// 시작 일시가 없는 공연은 예정으로 본다. 날짜가 미정이라는 뜻이지 지났다는
  /// 뜻이 아니다.
  bool isPast(DateTime now) {
    final start = startAt;
    return start != null && start.isBefore(now);
  }

  /// 공연까지 남은 날. 오늘이면 0, 이미 지났으면 음수, 날짜 미정이면 null.
  ///
  /// 시각이 아니라 날짜로 센다. 오늘 저녁 공연은 `D-DAY` 여야지 시각 차이를
  /// 반올림해 `D-1` 이 되면 안 된다.
  int? daysUntil(DateTime now) {
    final start = startAt;
    if (start == null) return null;
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(
      start.year,
      start.month,
      start.day,
    ).difference(today).inDays;
  }

  /// 지금 입장 QR 을 열 수 있는가.
  ///
  /// 티켓이 손에 있고([TicketStatus.isUsable]) 공연 시간대에 들어왔을 때만
  /// 연다. 창의 앞뒤 폭은 [TicketMetrics.qrOpensBefore] · [TicketMetrics.qrClosesAfter] 참고.
  bool canEnter(DateTime now) {
    final start = startAt;
    if (!status.isUsable || start == null) return false;
    return now.isAfter(start.subtract(TicketMetrics.qrOpensBefore)) &&
        now.isBefore(start.add(TicketMetrics.qrClosesAfter));
  }

  /// 지금 예매를 취소할 수 있는가. 발행이 끝난 티켓만, 공연 24시간 전까지다.
  ///
  /// 날짜가 미정인 공연은 마감을 계산할 수 없어 막는다. 서버도 같은 자리에서
  /// 거절하므로, 눌러 놓고 실패를 받느니 버튼을 잠그는 쪽이 낫다.
  bool canCancel(DateTime now) {
    final start = startAt;
    if (!status.isUsable || start == null) return false;
    return now.isBefore(start.subtract(TicketMetrics.cancelDeadline));
  }

  /// 상태만 바꾼 사본. 취소 직후처럼 서버를 다시 부르지 않고 한 장만 갱신할 때.
  MyTicket copyWith({TicketStatus? status}) => MyTicket(
    reservationId: reservationId,
    ticketId: ticketId,
    concertId: concertId,
    title: title,
    venueName: venueName,
    sectionName: sectionName,
    seatRow: seatRow,
    seatNumber: seatNumber,
    facePrice: facePrice,
    status: status ?? this.status,
    bookedAt: bookedAt,
    posterImageUrl: posterImageUrl,
    startAt: startAt,
  );

  /// 서버는 `LocalDateTime` 을 시간대 없는 ISO 문자열(`2026-10-10T19:00:00`)로
  /// 준다. `DateTime.parse` 는 이를 기기 현지 시각으로 읽는다.
  static DateTime? _dateTimeOrNull(Object? value) =>
      value is String ? DateTime.parse(value) : null;
}
