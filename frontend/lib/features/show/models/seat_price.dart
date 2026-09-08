import '../../../core/utils/formatters.dart';

/// 좌석 등급 한 줄. (예: `모든 좌석` · 186,000원)
///
/// 시안에는 등급이 하나뿐이지만 목록으로 받는다. 등급이 늘어도 카드가
/// 바뀌지 않고, 등급 구분이 없는 공연은 `모든 좌석` 한 줄로 같은 모양이 된다.
class SeatPrice {
  const SeatPrice({required this.grade, required this.price});

  /// 등급 이름. 구분이 없는 공연은 `모든 좌석`.
  final String grade;

  final int price;

  /// 카드에 찍는 금액 문구. (예: `186,000원`)
  String get priceLabel => formatWon(price);
}
