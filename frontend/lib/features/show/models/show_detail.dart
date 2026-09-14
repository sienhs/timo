import '../../../core/utils/formatters.dart';
import 'seat_price.dart';
import 'show_artist.dart';

/// 공연 상세 한 건.
///
/// 목록용 `ShowSummary` 와 겹치는 필드가 있지만 상속·재사용하지 않는다.
/// 목록은 카드 한 장에 들어갈 만큼만 필요하고, 상세는 장소·가격·아티스트·
/// 안내문까지 들고 있어야 한다. 서버에서도 목록 응답과 상세 응답이 갈린다.
///
/// **오픈 여부를 필드로 두지 않는다.** 상태를 `isOpen` 같은 bool 로 받으면
/// 화면을 열어 둔 채로 오픈 시각이 지나도 값이 그대로라 하단 바가 바뀌지
/// 않는다. 기준 시각을 받아 그때그때 판정한다 — 테스트에서 시간을 고정할
/// 수 있는 것도 같은 이유다.
class ShowDetail {
  const ShowDetail({
    required this.id,
    required this.title,
    required this.venue,
    required this.posterAsset,
    required this.startAt,
    this.endAt,
    this.ticketOpenAt,
    required this.seatPrices,
    required this.artists,
    required this.notice,
  });

  final String id;
  final String title;

  /// 공연장 이름.
  final String venue;

  /// 포스터 이미지 경로. 서버 연동 시 URL 로 바뀐다.
  final String posterAsset;

  /// 공연 시작일.
  final DateTime startAt;

  /// 마지막 공연일. 하루짜리 공연은 null 이다.
  ///
  /// 요구사항이 **좌석 지정 방식의 단일 회차 공연**으로 한정하고 있어
  /// (`Requirements_Definition_Document.md`) 실제로는 늘 null 이다. 회차가
  /// 하나뿐이라 고를 날짜가 없고, 그래서 날짜 선택 화면도 두지 않는다.
  /// 필드를 남겨 둔 것은 서버 응답에 종료일이 들어 있기 때문이다 — 다회차가
  /// 허용되면 회차 목록과 회차별 좌석표가 함께 생겨야 한다.
  final DateTime? endAt;

  /// 티켓 예매 오픈 일시. 이미 오픈했거나 오픈 일정이 없는 공연은 null 이다.
  final DateTime? ticketOpenAt;

  /// 등급별 가격. 최소 한 줄은 있다.
  final List<SeatPrice> seatPrices;

  final List<ShowArtist> artists;

  /// 안내 문단. 문단 사이 간격은 화면이 준다 — 문자열에 빈 줄을 넣으면
  /// 간격을 바꿀 때 데이터를 고쳐야 한다.
  final List<String> notice;

  /// 화면에 찍는 공연 기간. (예: `2026.11.01 ~ 12.31`)
  String get periodLabel => formatShowPeriod(startAt, endAt);

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
}
