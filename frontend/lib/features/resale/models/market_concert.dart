import 'wire_time.dart';

/// 양도 매물이 올라와 있는 공연 하나. 서버 `MarketConcertSummaryResponseDto`
/// 한 건이다. 공연마다 매물 수와 최저가만 오고 개별 매물은 공연을 고른 뒤 따로
/// 받는다. 매물이 없는 공연은 아예 오지 않으므로 [listingCount] 는 늘 1 이상이다.
class MarketConcert {
  const MarketConcert({
    required this.concertId,
    required this.title,
    required this.venueName,
    required this.listingCount,
    required this.lowestPrice,
    this.posterImageUrl,
    this.startAt,
    this.endAt,
  });

  factory MarketConcert.fromJson(Map<String, dynamic> json) => MarketConcert(
    concertId: (json['concertId'] as num).toInt(),
    title: json['title'] as String,
    venueName: json['venueName'] as String,
    listingCount: (json['listingCount'] as num).toInt(),
    lowestPrice: (json['lowestPrice'] as num).toInt(),
    posterImageUrl: json['posterImageUrl'] as String?,
    startAt: dateTimeOrNull(json['startDate']),
    endAt: dateTimeOrNull(json['endDate']),
  );

  final int concertId;
  final String title;
  final String venueName;

  /// 지금 살 수 있는 매물 수.
  final int listingCount;

  /// 그중 가장 싼 등록가(원).
  final int lowestPrice;

  /// 포스터 주소. 포스터가 없는 공연이면 null.
  final String? posterImageUrl;

  /// 공연 시작·종료 일시. 아직 정해지지 않았으면 null 이다.
  final DateTime? startAt;
  final DateTime? endAt;
}
