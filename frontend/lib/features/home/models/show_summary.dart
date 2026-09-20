import '../../../core/utils/formatters.dart';
import '../constants.dart';

/// 목록·카드에 필요한 만큼만 담은 공연 요약. 서버의 공연 목록 응답
/// (`ConcertSummaryResponseDto`) 한 건이다.
///
/// MVP 는 콘서트만 다룬다. 그래서 분류(카테고리) 필드를 두지 않는다 —
/// 값이 하나뿐인 필드는 화면마다 "콘서트"만 찍게 만들 뿐이고, 필터로 쓰면
/// 아무것도 걸러지지 않는 조작부가 남는다. 뮤지컬·연극이 들어오면 그때
/// 분류를 추가하고 검색 화면에 칩 줄을 붙인다.
///
/// 예매 도메인의 `Performance` 와 필드가 겹치지만 합치지 않는다. 저쪽은 한
/// 공연의 예매에 필요한 정보(수수료·회차)를 들고 있고, 이쪽은 여러 공연을
/// 나열하는 데 필요한 정보(기간·오픈 일시)를 들고 있어서, 바뀌는 이유가
/// 서로 다르다.
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

  /// 서버 응답 한 건을 읽는다.
  ///
  /// 오픈 일시는 **아직 오픈하지 않은 공연**에만 담는다. 서버는 이미 오픈한
  /// 공연에도 `openAt` 을 주지만, 홈의 오픈 뱃지는 "언제 열리는가" 를 알리는
  /// 것이라 지난 시각을 찍으면 뜻이 어긋난다. 상태를 보고 여기서 한 번 거른다.
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

  /// 서버가 준 공연 id. 상세 조회에 쓴다.
  final int id;

  final String title;

  /// 공연장 이름. 카드에는 없고 검색 결과 줄에 찍는다.
  final String venueName;

  /// 예매 상태. 백엔드 `ConcertStatus` 의 상수명 그대로다. 다섯 가지 중
  /// 화면이 구분하는 것은 [upcomingStatus] 와 [onSaleStatus] 둘뿐이라 enum 으로
  /// 옮기지 않았다 — 나머지(매진·종료·취소)를 따로 그리게 되면 그때 옮긴다.
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
  ///
  /// 상태만으로 가르지 않는 이유가 있다. 서버는 오픈 시각이 지나도 온체인
  /// 등록이 끝나지 않은 공연을 `SCHEDULED` 로 남겨 둔다(백엔드
  /// `ConcertRepository.openScheduled` 의 organizer·showId 조건). 그 공연을
  /// 상태만 보고 그리면 오픈 예정 줄에 `오늘 11시 12분 오픈` 이 이미 지난
  /// 시각인 채로 하루 종일 남는다. 상태는 서버 사정이고, 이 줄이 답해야 하는
  /// 것은 "아직 열리지 않았는가" 다.
  ///
  /// 오픈 일시가 없으면(미정이거나 이미 오픈해 [fromJson] 이 버렸다) false 다.
  bool opensAfter(DateTime now) {
    final openAt = ticketOpenAt;
    return openAt != null && openAt.isAfter(now);
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
