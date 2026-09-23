import 'seat.dart';

/// 공연장 구역 하나. 서버 구역 목록 응답의 항목 하나다. 구역 자체는 공연장
/// 것이지만 잔여석은 공연마다 다르다.
class Zone {
  const Zone({
    required this.id,
    required this.name,
    required this.price,
    required this.seatCount,
    required this.availableCount,
    required this.rowCount,
    required this.seatsPerRow,
  });

  factory Zone.fromJson(Map<String, dynamic> json) => Zone(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String,
    price: (json['price'] as num).toInt(),
    seatCount: (json['seatCount'] as num).toInt(),
    availableCount: (json['availableCount'] as num).toInt(),
    rowCount: (json['rowCount'] as num?)?.toInt() ?? 0,
    seatsPerRow: (json['seatPerRow'] as num?)?.toInt() ?? 0,
  );

  /// 서버가 준 구역 번호. 좌석을 조회할 때 이 번호로 묻는다.
  final int id;

  /// '1층 A블록' — 배치도와 안내 문구에 그대로 쓴다. 공연장마다 부르는 방식이
  /// 달라 앱이 이름을 만들지 않는다.
  final String name;

  final int price;

  /// 이 구역에 등록된 자리 수.
  final int seatCount;

  /// 그중 아직 예매 가능한 자리 수. 요청한 공연 기준이다.
  final int availableCount;

  /// 배치도 격자의 크기. **좌석 수와 일치하지 않는다** — 통로로 비는 자리가
  /// 있기 때문이다. 스탠딩처럼 격자로 표현되지 않는 구역은 서버가 비워 주고,
  /// 그때는 0 이 되어 배치도를 그리지 않는다.
  final int rowCount;
  final int seatsPerRow;

  bool get isSoldOut => availableCount == 0;

  /// '1층 A블록 9열 6번' — 확인 다이얼로그·하단 바·결제 화면이 함께 쓴다.
  /// 좌석은 구역 이름을 들고 있지 않아 [Seat] 이 아니라 구역이 만든다.
  String seatLabel(Seat seat) => '$name ${seat.row}열 ${seat.number}번';
}
