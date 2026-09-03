/// 공연장 구역(FLOOR A/B/C). 요구사항상 좌석 등급은 성립하지 않고
/// 모든 좌석이 동일 금액이므로, 가격은 등급이 아니라 구역이 들고 있다.
/// (시안에서도 세 구역 모두 186,000원으로 같다)
class Zone {
  const Zone({
    required this.id,
    required this.name,
    required this.price,
    required this.rowCount,
    required this.seatsPerRow,
  });

  /// 'A' — 좌석 라벨과 라우트 인자로 쓰는 식별자
  final String id;

  /// 'FLOOR A' — 배치도에 노출하는 이름
  final String name;

  final int price;
  final int rowCount;
  final int seatsPerRow;

  /// 'A구역'
  String get shortLabel => '$id구역';

  int get totalSeats => rowCount * seatsPerRow;
}
