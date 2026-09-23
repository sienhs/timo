import '../../../core/utils/formatters.dart';
import '../constants.dart';

/// 목록·카드에 필요한 만큼만 담은 공연 요약. 서버의 공연 목록 응답
/// (`ConcertSummaryResponseDto`) 한 건이다. MVP 는 콘서트만 다뤄 분류 필드가
/// 없고, 예매 도메인의 `Performance` 와는 바뀌는 이유가 달라 합치지 않는다.
class ShowSummary {
  const ShowSummary({
    required this.id,
    required this.title,
    required this.venueName,
    required this.status,
    this.posterImageUrl,
    this.startAt,
    this.endAt,
    this.ticketOpenAt,
  });

  /// 서버 응답 한 건을 읽는다. 오픈 일시는 아직 오픈하지 않은 공연에만 담는다.
  /// 서버는 이미 오픈한 공연에도 `openAt` 을 주지만, 지난 시각을 오픈 뱃지에
  /// 찍으면 뜻이 어긋난다.
  factory ShowSummary.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String;
    final isUpcoming = status == upcomingStatus;
    return ShowSummary(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      venueName: json['venueName'] as String,
      status: status,
      posterImageUrl: json['posterImageUrl'] as String?,
      startAt: _dateTimeOrNull(json['startDate']),
      endAt: _dateTimeOrNull(json['endDate']),
      ticketOpenAt: isUpcoming ? _dateTimeOrNull(json['openAt']) : null,
    );
  }

  /// "등록됐고 아직 예매가 열리지 않음". 백엔드 `ConcertStatus` 의 상수명과 같다.
  static const upcomingStatus = 'SCHEDULED';

  /// "예매 진행 중". 백엔드 `ConcertStatus` 의 상수명과 같다.
  static const onSaleStatus = 'ON_SALE';

  /// 예매가 마감되는 시점. 공연 시작 이만큼 전부터는 선점·결제가 막힌다.
  /// 백엔드 `Concert.BOOKING_CUTOFF_HOURS` 와 같은 값이다.
  static const bookingCutoff = Duration(hours: 2);

  /// 서버가 준 공연 id. 상세 조회에 쓴다.
  final int id;

  final String title;

  /// 공연장 이름. 카드에는 없고 검색 결과 줄에 찍는다.
  final String venueName;

  /// 예매 상태. 백엔드 `ConcertStatus` 의 상수명 그대로다. 화면이 구분하는 것은
  /// [upcomingStatus] 와 [onSaleStatus] 둘뿐이다.
  final String status;

  /// 포스터 이미지 주소. 포스터가 없는 공연이면 null 이다.
  final String? posterImageUrl;

  /// 공연 시작일. 아직 정해지지 않았으면 null 이다.
  final DateTime? startAt;

  /// 마지막 공연일. 하루짜리 공연이거나 미정이면 null 이다.
  final DateTime? endAt;

  /// 티켓 예매 오픈 일시. 이미 오픈했거나 미정이면 null 이다.
  final DateTime? ticketOpenAt;

  /// 예매를 앞두고 있거나 진행 중인가. 검색 결과의 "오픈 예정 / 예매중" 섹션과
  /// 홈의 인기 공연 줄이 이걸로 거른다.
  bool get isOpenOrUpcoming =>
      status == upcomingStatus || status == onSaleStatus;

  /// 오픈 시각이 아직 남았는가. 홈의 "티켓 오픈 예정" 줄이 이걸로 거른다.
  /// 서버는 오픈 시각이 지나도 온체인 등록이 안 끝난 공연을 `SCHEDULED` 로 남겨
  /// 두므로 상태만으로 가르지 않는다. 오픈 일시가 없으면 false 다.
  bool opensAfter(DateTime now) {
    final openAt = ticketOpenAt;
    return openAt != null && openAt.isAfter(now);
  }

  /// 지금 이 공연을 예매할 수 있는가. 인기 공연 줄의 상태 뱃지가 이걸로 가른다.
  /// 서버의 `ON_SALE` 은 공연 시작 [bookingCutoff] 전 마감 뒤에도 남아 있어
  /// 상태만 보지 않고 백엔드 `Concert.bookingBlockReason` 과 같은 식을 여기서
  /// 유도한다. 공연 시작일이 없으면 예매할 수 없는 것으로 본다.
  bool isBookableNow(DateTime now) {
    final start = startAt;
    if (status != onSaleStatus || start == null) return false;
    return now.isBefore(start.subtract(bookingCutoff));
  }

  /// 카드에 찍는 기간 문구. (예: `2026.07.05 ~ 07.07`)
  String get periodLabel {
    final start = startAt;
    if (start == null) return HomeStrings.periodUndecided;
    return formatShowPeriod(start, endAt);
  }

  /// 서버는 `LocalDateTime` 을 시간대 없는 ISO 문자열(`2026-10-10T19:00:00`)로
  /// 준다. `DateTime.parse` 는 이를 기기 현지 시각으로 읽는다.
  static DateTime? _dateTimeOrNull(Object? value) =>
      value is String ? DateTime.parse(value) : null;
}
