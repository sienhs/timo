import '../constants.dart';
import 'ticket_acquisition.dart';
import 'ticket_status.dart';

/// 내가 지금 가진 티켓 한 장. 서버 내 티켓 목록 응답
/// (`MyTicketSummaryResponseDto`, `GET /api/v1/tickets/me`) 한 건이다.
///
/// **소유 기준**이다. 예매 목록으로 그리던 때(S15P21D206-168)는 "내가 예매한
/// 이력" 이라 양도로 판 티켓이 남고 산 티켓은 안 보였다. 이 목록은 판 티켓이
/// 빠지고 산 티켓이 들어온다(S15P21D206-331). 필드 이름은 백엔드가 예매 목록과
/// 맞춰 뒀다.
///
/// 예정 공연과 지난 공연이 같은 모델이다. 서버가 그 둘을 나눠 주지 않고
/// ([isPast] 로 화면이 가른다) 카드에 들어가는 값도 같아서, 나누면 똑같은
/// 필드를 가진 클래스가 둘 생길 뿐이다.
class MyTicket {
  const MyTicket({
    required this.ticketId,
    required this.reservationId,
    required this.concertId,
    required this.title,
    required this.venueName,
    required this.sectionName,
    required this.seatRow,
    required this.seatNumber,
    required this.facePrice,
    required this.status,
    required this.listed,
    required this.acquiredBy,
    required this.acquiredAt,
    this.posterImageUrl,
    this.startAt,
  });

  factory MyTicket.fromJson(Map<String, dynamic> json) => MyTicket(
    ticketId: (json['ticketId'] as num).toInt(),
    reservationId: (json['reservationId'] as num).toInt(),
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
    status: TicketStatus.fromWire(json['ticketStatus']),
    listed: json['listed'] as bool? ?? false,
    acquiredBy: TicketAcquisition.fromWire(json['acquiredBy']),
    acquiredAt: DateTime.parse(json['acquiredAt'] as String),
    posterImageUrl: json['posterImageUrl'] as String?,
    startAt: _dateTimeOrNull(json['startDate']),
  );

  /// 티켓 id. 이 목록의 주 식별자다. 입장 QR 발급과 양도 등록이 받는 번호다.
  final int ticketId;

  /// 이 티켓을 발행한 예매의 id. 취소할 때 쓴다.
  ///
  /// **양도로 받은 티켓이면 판 사람의 예매다**([acquiredBy]). 그 번호로 취소를
  /// 걸면 404 라, 취소는 [isBooked] 일 때만 연다.
  final int reservationId;

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

  /// 표의 상태. 발행 중·보유·양도 등록됨·입장 완료·회수됨 …
  final TicketStatus status;

  /// 지금 양도 마켓에 올라가 있는가. 서버가 매물 테이블을 봐서 준다.
  final bool listed;

  /// 직접 예매했는지, 양도로 받았는지.
  final TicketAcquisition acquiredBy;

  /// 내 것이 된 시각. 예매면 예매 시각, 양도면 체결 시각이다.
  ///
  /// 양도받은 티켓에 판 사람의 예매 시각을 "예매한 날" 로 찍으면 거짓말이라
  /// 서버가 따로 준다.
  final DateTime acquiredAt;

  /// 포스터 주소. 포스터가 없는 공연이면 null.
  final String? posterImageUrl;

  /// 공연 시작 일시. 아직 정해지지 않았으면 null.
  final DateTime? startAt;

  /// 카드에 찍는 좌석. (예: `R석 12열 24번`)
  String get seatLabel => '$sectionName $seatRow열 $seatNumber번';

  /// 지금 양도 등록 중인가.
  ///
  /// 서버가 `listed` 를 따로 주고 상태값 [TicketStatus.listed] 도 있다. 둘 중
  /// 하나라도 켜져 있으면 등록 중으로 본다 — 백엔드 주석은 `listed` 를 기준으로
  /// 삼으라고 하고, 상태값은 그 뜻을 한 번 더 말하는 것이다.
  bool get isListed => listed || status == TicketStatus.listed;

  /// 표가 손에 있고 마켓에 올라가 있지 않다. 입장·취소·양도 등록이 이때만 된다.
  bool get isUsable => status.isOwned && !isListed;

  /// 표가 손에 있다 — 쓸 수 있거나, 마켓에 올라가 있어 잠깐 잠긴 상태다.
  ///
  /// 더보기(⋮)를 열어 줄 기준이다. 등록 중인 티켓에도 열어서 "왜 못 하는지"
  /// 를 시트가 알려주게 한다. 발행 중·입장 완료·회수·환불은 할 수 있는 일이
  /// 없어 열지 않는다.
  bool get isHeld => status.isOwned || isListed;

  /// 표가 사라졌다(회수·환불). 목록에서 지우지 않고 회색 카드로 남긴다.
  bool get isVoided => status.isVoided;

  /// 직접 예매한 티켓인가. 예매 취소와 주문 상세는 이때만 내 것이다.
  bool get isBooked => acquiredBy == TicketAcquisition.booking;

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
  /// 표가 손에 있고([isUsable]) 공연 시간대에 들어왔을 때만 연다. 창의 앞뒤
  /// 폭은 [TicketMetrics.qrOpensBefore] · [TicketMetrics.qrClosesAfter] 참고.
  /// 발행 중·양도 등록 중·입장 완료는 서버가 409 로 거절하는 상태라 여기서
  /// 미리 잠근다.
  bool canEnter(DateTime now) {
    final start = startAt;
    if (!isUsable || start == null) return false;
    return now.isAfter(start.subtract(TicketMetrics.qrOpensBefore)) &&
        now.isBefore(start.add(TicketMetrics.qrClosesAfter));
  }

  /// 지금 예매를 취소할 수 있는가. 직접 예매한 표가 손에 있을 때만, 공연
  /// 24시간 전까지다.
  ///
  /// 날짜가 미정인 공연은 마감을 계산할 수 없어 막는다. 서버도 같은 자리에서
  /// 거절하므로, 눌러 놓고 실패를 받느니 버튼을 잠그는 쪽이 낫다.
  bool canCancel(DateTime now) {
    final start = startAt;
    if (!isUsable || !isBooked || start == null) return false;
    return now.isBefore(start.subtract(TicketMetrics.cancelDeadline));
  }

  /// 상태만 바꾼 사본. 취소 직후처럼 서버를 다시 부르지 않고 한 장만 갱신할 때.
  MyTicket copyWith({TicketStatus? status, bool? listed}) => MyTicket(
    ticketId: ticketId,
    reservationId: reservationId,
    concertId: concertId,
    title: title,
    venueName: venueName,
    sectionName: sectionName,
    seatRow: seatRow,
    seatNumber: seatNumber,
    facePrice: facePrice,
    status: status ?? this.status,
    listed: listed ?? this.listed,
    acquiredBy: acquiredBy,
    acquiredAt: acquiredAt,
    posterImageUrl: posterImageUrl,
    startAt: startAt,
  );

  /// 서버는 `LocalDateTime` 을 시간대 없는 ISO 문자열(`2026-10-10T19:00:00`)로
  /// 준다. `DateTime.parse` 는 이를 기기 현지 시각으로 읽는다.
  static DateTime? _dateTimeOrNull(Object? value) =>
      value is String ? DateTime.parse(value) : null;
}
