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

/// 서버가 준 상태 문자열을 읽는다.
///
/// 모르는 값은 **예매 진행 중**으로 본다. 좌석 상태가 모르는 값을
/// 고를 수 없는 자리로 보는 것과 반대인데, 막았을 때의 손해가 서로 다르기
/// 때문이다. 좌석은 잘못 열어 주면 잡는 순간 거절당하고 끝이지만, 공연을 잘못
/// 닫으면 팔고 있는 공연에 '종료된 공연입니다' 가 붙어 살 길이 사라진다.
/// 실제로 못 파는 공연이면 서버가 예매 단계에서 거절한다.
ShowStatus showStatusOf(Object? raw) => switch (raw) {
  'SCHEDULED' => ShowStatus.scheduled,
  'SOLD_OUT' => ShowStatus.soldOut,
  'CLOSED' => ShowStatus.closed,
  'CANCELED' => ShowStatus.canceled,
  _ => ShowStatus.onSale,
};

/// 공연 상세 한 건. 서버의 공연 단건 응답에 구역별 가격을 더한 것이다.
///
/// 목록용 `ShowSummary` 와 겹치는 필드가 있지만 상속·재사용하지 않는다.
/// 목록은 카드 한 장에 들어갈 만큼만 필요하고, 상세는 장소·가격·아티스트까지
/// 들고 있어야 한다. 서버에서도 목록 응답과 상세 응답이 갈린다.
///
/// **오픈 여부를 필드로 두지 않는다.** 상태를 `isOpen` 같은 bool 로 받으면
/// 화면을 열어 둔 채로 오픈 시각이 지나도 값이 그대로라 하단 바가 바뀌지
/// 않는다. 기준 시각을 받아 그때그때 판정한다 — 테스트에서 시간을 고정할
/// 수 있는 것도 같은 이유다.
///
/// 서버가 주는 설명글·상세 이미지·연령등급·조회수는 담지 않는다. 시안에 그릴
/// 자리가 없어서다. 화면에 안 쓰는 값을 모델에 두면 어디까지가 실제로 쓰이는
/// 정보인지 읽는 사람이 매번 확인해야 한다.
class ShowDetail {
  const ShowDetail({
    required this.id,
    required this.title,
    required this.venue,
    this.posterUrl,
    required this.startAt,
    this.ticketOpenAt,
    required this.status,
    required this.zonePrices,
    required this.artists,
  });

  /// 공연 상세 응답을 읽는다. 가격은 구역 목록에서 따로 받아 넘겨준다 —
  /// 상세 응답에는 금액이 들어 있지 않다.
  factory ShowDetail.fromJson(
    Map<String, dynamic> json, {
    required List<ZonePrice> zonePrices,
  }) => ShowDetail(
    id: (json['id'] as num).toInt(),
    title: json['title'] as String,
    venue: json['venueName'] as String,
    posterUrl: json['posterImageUrl'] as String?,
    startAt: DateTime.parse(json['startDate'] as String),
    ticketOpenAt: _dateTimeOrNull(json['openAt']),
    status: showStatusOf(json['status']),
    zonePrices: zonePrices,
    artists: (json['artists'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ShowArtist.fromJson)
        .toList(),
  );

  final int id;
  final String title;

  /// 공연장 이름.
  final String venue;

  /// 포스터 이미지 주소. 포스터가 없는 공연이면 null 이다.
  final String? posterUrl;

  /// 공연일.
  ///
  /// 서버는 종료일도 주지만 읽지 않는다. 요구사항이 **좌석 지정 방식의 단일
  /// 회차 공연**으로 한정하고 있어(`Requirements_Definition_Document.md`)
  /// 고를 회차가 없고, 그래서 날짜 선택 화면도 두지 않는다. 기간으로 찍으면
  /// 고를 날이 있는 것처럼 읽힌다.
  final DateTime startAt;

  /// 티켓 예매 오픈 일시. 오픈 일정이 없는 공연은 null 이다.
  final DateTime? ticketOpenAt;

  final ShowStatus status;

  /// 구역별 가격. 구역 목록 응답에서 만든다.
  final List<ZonePrice> zonePrices;

  final List<ShowArtist> artists;

  /// 끝났거나 취소돼서 이제 예매할 수 없는 공연인지.
  ///
  /// 매진은 여기 넣지 않는다. 취소표가 돌아올 수 있어 들어가 볼 이유가 있다.
  bool get isFinished =>
      status == ShowStatus.closed || status == ShowStatus.canceled;

  /// 화면에 찍는 공연일. (예: `2026.11.01`)
  String get dateLabel => formatShowPeriod(startAt);

  /// [now] 기준으로 예매를 열었는지.
  ///
  /// 오픈 일시가 없는 공연은 열려 있는 것으로 본다 — 오픈 예정이라는 정보가
  /// 없는데 예매를 막으면 들어갈 길이 사라진다.
  bool isOpenAt(DateTime now) {
    final openAt = ticketOpenAt;
    return openAt == null || !now.isBefore(openAt);
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
