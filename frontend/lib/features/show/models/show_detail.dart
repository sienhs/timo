import '../../../core/utils/formatters.dart';
import 'show_artist.dart';
import 'zone_price.dart';

/// 공연의 예매 상태. 백엔드 `ConcertStatus` 의 상수명과 같다.
enum ShowStatus {
  /// 등록됐고 아직 예매가 열리지 않음.
  scheduled,

  /// 예매 진행 중.
  onSale,

  /// 잔여 좌석 소진.
  soldOut,

  /// 공연 종료.
  closed,

  /// 공연 취소.
  canceled,
}

/// 서버가 준 상태 문자열을 읽는다. 모르는 값은 **예매 진행 중**으로 본다 —
/// 공연을 잘못 닫으면 팔고 있는 공연에 '종료' 가 붙어 살 길이 사라지지만,
/// 잘못 열어도 실제로 못 파는 공연이면 서버가 예매 단계에서 거절한다.
ShowStatus showStatusOf(Object? raw) => switch (raw) {
  'SCHEDULED' => ShowStatus.scheduled,
  'SOLD_OUT' => ShowStatus.soldOut,
  'CLOSED' => ShowStatus.closed,
  'CANCELED' => ShowStatus.canceled,
  _ => ShowStatus.onSale,
};

/// 서버가 예매를 막은 이유. 백엔드 `BookingBlockReason` 의 상수명과 같다.
/// 다만 서버의 `CLOSED` 는 예매 마감이지 공연 종료가 아니라, 공연 종료를 뜻하는
/// [ShowStatus.closed] 와 헷갈리지 않게 `bookingClosed` 로 적는다.
enum ShowBlockReason {
  /// 예매 중인 공연이 아니다. 매진·종료·취소는 물론, 오픈 시각이 지났는데도
  /// 서버가 아직 열지 않은 공연까지 전부 여기로 온다. 무엇인지는 이 값만으로
  /// 가를 수 없어 [ShowDetail.status] 를 함께 봐야 한다.
  notOnSale,

  /// 예매 중이지만 아직 오픈 시각 전이다.
  notOpen,

  /// 공연 시작이 가까워 예매가 마감됐다. 공연 자체는 아직 남아 있다.
  bookingClosed,
}

/// 서버가 준 사유 문자열을 읽는다. 예매가 되는 공연은 이 값이 없어 null 이다.
/// 모르는 값도 null 로 본다 — 서버가 사유를 하나 늘린 날 멀쩡한 공연이 앱에서만
/// 닫히지 않게. 실제로 못 파는 공연이면 좌석을 잡는 단계에서 서버가 거절한다.
ShowBlockReason? showBlockReasonOf(Object? raw) => switch (raw) {
  'NOT_ON_SALE' => ShowBlockReason.notOnSale,
  'NOT_OPEN' => ShowBlockReason.notOpen,
  'CLOSED' => ShowBlockReason.bookingClosed,
  _ => null,
};

/// 하단 바와 상태 뱃지가 함께 보는 예매 단계. "지금 어느 국면인가" 만 답하고,
/// 뱃지를 달지 버튼을 잠글지는 각 위젯이 정한다.
enum ShowBookingPhase {
  /// 예매를 받는 중. 매진도 여기 포함한다 - 취소표가 돌아올 수 있어 들어가 볼
  /// 이유가 있다.
  onSale,

  /// 오픈 전. **언제 열리는지 안다.**
  upcoming,

  /// 오픈 시각은 지났는데 서버가 아직 열어 주지 않았다. **언제 열릴지 모른다.**
  /// 온체인 등록을 못 끝냈거나 하는 사정이라 시간이 해결해 주지 않고 남은 시간도 셀 수 없다.
  awaitingOpen,

  /// 공연 시작이 가까워 예매가 마감됐다. 공연 자체는 아직 남아 있다.
  bookingClosed,

  /// 공연이 끝났다.
  finished,

  /// 공연이 취소됐다.
  canceled,
}

/// 공연 상세 한 건. 서버의 공연 단건 응답을 화면이 쓰는 모양으로 옮긴 것이다.
/// 오픈 여부는 bool 필드가 아니라 기준 시각을 받아 그때그때 판정한다 — 화면을 열어 둔
/// 채 오픈 시각이 지나도 하단 바가 바뀌고, 테스트에서 시간을 고정할 수 있다. 시간으로
/// 풀리지 않는 사정은 서버가 준 [bookable] 이 답한다.
class ShowDetail {
  const ShowDetail({
    required this.id,
    required this.title,
    required this.venue,
    this.posterUrl,
    required this.startAt,
    this.ticketOpenAt,
    required this.status,
    this.bookable = true,
    this.blockReason,
    required this.zonePrices,
    required this.artists,
    this.imageUrls = const [],
  });

  /// 공연 상세 응답을 읽는다. 가격도 이 응답 안에 들어 있다.
  factory ShowDetail.fromJson(Map<String, dynamic> json) => ShowDetail(
    id: (json['id'] as num).toInt(),
    title: json['title'] as String,
    venue: json['venueName'] as String,
    posterUrl: json['posterImageUrl'] as String?,
    startAt: DateTime.parse(json['startDate'] as String),
    ticketOpenAt: _dateTimeOrNull(json['openAt']),
    status: showStatusOf(json['status']),
    bookable: json['bookable'] as bool? ?? true,
    blockReason: showBlockReasonOf(json['blockReason']),
    zonePrices: (json['sectionPrices'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ZonePrice.fromJson)
        .toList(),
    artists: (json['artists'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ShowArtist.fromJson)
        .toList(),
    imageUrls: (json['imageUrls'] as List? ?? const [])
        .whereType<String>()
        .toList(),
  );

  final int id;
  final String title;

  /// 공연장 이름.
  final String venue;

  /// 포스터 이미지 주소. 포스터가 없는 공연이면 null 이다.
  final String? posterUrl;

  /// 공연일. 서버는 종료일도 주지만 읽지 않는다 — 요구사항이 단일 회차 공연으로
  /// 한정하고 있어 고를 회차가 없고, 기간으로 찍으면 고를 날이 있는 것처럼 읽힌다.
  final DateTime startAt;

  /// 티켓 예매 오픈 일시. 오픈 일정이 없는 공연은 null 이다.
  final DateTime? ticketOpenAt;

  final ShowStatus status;

  /// 서버가 이 공연의 예매를 받아 주는지. 응답을 만든 **그 시각의** 판정이다.
  /// 상태 컬럼은 서버가 1분마다 미는 거친 라벨이라, 오픈 직후 잠깐은 `SCHEDULED` 인데
  /// 예매는 열려 있고, 마감부터 공연 종료까지는 `ON_SALE` 인데 예매는 막혀 있다.
  /// 기본값이 참인 것은 [showStatusOf] 가 모르는 상태를 예매 중으로 보는 것과 같은 판단이다.
  final bool bookable;

  /// [bookable] 이 거짓일 때 그 이유. 예매가 되는 공연이면 null 이다.
  final ShowBlockReason? blockReason;

  /// 구역별 가격. 구역 목록 응답에서 만든다.
  final List<ZonePrice> zonePrices;

  final List<ShowArtist> artists;

  /// 공연별 상세 안내 이미지. 서버 응답 순서를 유지한다.
  final List<String> imageUrls;

  /// 화면에 찍는 공연 일시. (예: `2026.11.01 (일) 19:00`) 상세가 공연 시각을 적는
  /// 유일한 자리다. 요일까지 붙이는 것은 좌석 선택 화면의 공연 정보 바와 같은 형식이다.
  String get dateTimeLabel => formatPerformedAtWithWeekday(startAt);

  /// [now] 기준으로 예매를 열었는지. 오픈 일시가 없는 공연은 열려 있는 것으로 본다 —
  /// 오픈 예정이라는 정보가 없는데 예매를 막으면 들어갈 길이 사라진다.
  bool isOpenAt(DateTime now) {
    final openAt = ticketOpenAt;
    return openAt == null || !now.isBefore(openAt);
  }

  /// [now] 기준 예매 단계. 뱃지와 하단 바가 같은 답을 보게 판정을 여기 하나로 모은다.
  /// 위에서부터 걸리는 것이 답이다. 순서 자체가 규칙이라 줄을 옮기면 뜻이 바뀐다.
  ShowBookingPhase phaseAt(DateTime now) {
    if (status == ShowStatus.canceled) return ShowBookingPhase.canceled;
    if (status == ShowStatus.closed) return ShowBookingPhase.finished;

    // 마감은 종료보다 뒤, 나머지보다 앞이다. 공연이 남은 동안 예매만 닫힌 구간이라
    // '종료' 로 뭉치면 안 되고, 매진이든 오픈 전이든 마감을 지났으면 살 수 없는 건 같다.
    if (blockReason == ShowBlockReason.bookingClosed) {
      return ShowBookingPhase.bookingClosed;
    }

    // 매진은 막지 않는다. 서버는 매진도 '예매 중이 아님' 으로 답하므로, 여기서
    // 먼저 걸러내지 않으면 아래 [bookable] 판정에 걸려 들어갈 길이 막힌다.
    if (status == ShowStatus.soldOut) return ShowBookingPhase.onSale;

    // 시간이 풀어 주는 것은 앱이 판정한다. 화면을 열어 둔 채 오픈 시각을
    // 넘기면 여기서부터 아래로 내려가 저절로 열린다.
    if (!isOpenAt(now)) return ShowBookingPhase.upcoming;

    // 시간으로 풀리지 않는 것은 서버가 답한다.
    if (!bookable) return ShowBookingPhase.awaitingOpen;

    return ShowBookingPhase.onSale;
  }

  /// 오픈까지 남은 시간. 이미 열렸으면 [Duration.zero].
  Duration remainingUntilOpenAt(DateTime now) {
    final openAt = ticketOpenAt;
    if (openAt == null) return Duration.zero;
    final remaining = openAt.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// 서버는 `LocalDateTime` 을 시간대 없는 ISO 문자열(`2026-10-10T19:00:00`)로
  /// 준다. `DateTime.parse` 는 이를 기기 현지 시각으로 읽는다.
  static DateTime? _dateTimeOrNull(Object? value) =>
      value is String ? DateTime.parse(value) : null;
}
