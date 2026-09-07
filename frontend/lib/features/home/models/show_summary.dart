import '../../../core/utils/formatters.dart';

/// 목록·카드에 필요한 만큼만 담은 공연 요약.
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
    required this.posterAsset,
    required this.startAt,
    this.endAt,
    this.ticketOpenAt,
  });

  final String id;
  final String title;

  /// 포스터 이미지 경로. 서버 연동 시 URL 로 바뀐다.
  final String posterAsset;

  /// 공연 시작일.
  final DateTime startAt;

  /// 마지막 공연일. 하루짜리 공연은 null 이다.
  final DateTime? endAt;

  /// 티켓 예매 오픈 일시. 이미 오픈한 공연은 null 이다.
  final DateTime? ticketOpenAt;

  /// 카드에 찍는 기간 문구. (예: `2026.07.05 ~ 07.07`)
  String get periodLabel => formatShowPeriod(startAt, endAt);
}
