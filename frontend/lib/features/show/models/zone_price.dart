import '../../../core/utils/formatters.dart';

/// 구역 한 줄의 가격. (예: `1층 A블록` · 150,000원)
///
/// 등급별이 아니라 구역별인 이유: 서버에 좌석 등급이 하나뿐이라(`COMMON`)
/// 등급으로 묶으면 공연장 전체가 한 줄로 합쳐져 가격대가 사라진다. 실제로
/// 금액이 갈리는 단위는 구역이고, 예매 화면의 '좌석가격보기' 도 구역으로 낸다.
class ZonePrice {
  const ZonePrice({required this.zoneName, required this.price});

  /// 구역 목록 응답의 구역 한 건을 읽는다.
  factory ZonePrice.fromJson(Map<String, dynamic> json) => ZonePrice(
    zoneName: json['name'] as String,
    price: (json['price'] as num).toInt(),
  );

  /// 구역 이름. 서버가 준 값을 그대로 쓴다.
  final String zoneName;

  final int price;

  /// 카드에 찍는 금액 문구. (예: `150,000원`)
  String get priceLabel => formatWon(price);
}
