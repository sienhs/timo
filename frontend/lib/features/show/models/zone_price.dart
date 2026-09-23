import '../../../core/utils/formatters.dart';

/// 구역 한 줄의 가격. (예: `1층 A블록` · 150,000원)
/// 서버에 좌석 등급이 `COMMON` 하나뿐이라 등급이 아니라 구역으로 묶는다.
class ZonePrice {
  const ZonePrice({required this.zoneName, required this.price});

  /// 공연 상세 응답의 `sectionPrices` 한 건을 읽는다. 구역 이름 키가 구역 목록
  /// 응답(`GET /api/v1/sections`)은 `name`, 여기서는 `sectionName` 이다.
  factory ZonePrice.fromJson(Map<String, dynamic> json) => ZonePrice(
    zoneName: json['sectionName'] as String,
    price: (json['price'] as num).toInt(),
  );

  /// 구역 이름. 서버가 준 값을 그대로 쓴다.
  final String zoneName;

  final int price;

  /// 카드에 찍는 금액 문구. (예: `150,000원`)
  String get priceLabel => formatWon(price);
}
