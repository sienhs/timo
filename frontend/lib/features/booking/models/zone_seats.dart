import 'seat.dart';

/// 구역 하나의 좌석 배치도. 서버 좌석 목록 응답 한 건이다. 구역 정보(이름·가격)를
/// 응답 머리에 한 번 싣는 서버 구조 그대로라, 좌석 화면은 구역 목록을 다시 받지
/// 않고도 제목과 금액을 그릴 수 있다.
class ZoneSeats {
  const ZoneSeats({
    required this.zoneId,
    required this.zoneName,
    required this.price,
    required this.seatCount,
    required this.availableCount,
    required this.rows,
  });

  /// 서버 응답을 배치도 순서(열 → 자리)의 중첩 리스트로 바꾼다. 통로로 비는
  /// 자리는 목록에서 빠져 오므로 받은 순서대로 줄 세우지 않고, 좌석이 말하는
  /// 열·번호 자리에 직접 꽂고 빈 곳은 null 로 남긴다.
  factory ZoneSeats.fromJson(Map<String, dynamic> json) {
    final seats = (json['seats'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Seat.fromJson)
        .toList();

    return ZoneSeats(
      zoneId: (json['sectionId'] as num).toInt(),
      zoneName: json['sectionName'] as String,
      price: (json['price'] as num).toInt(),
      seatCount: (json['seatCount'] as num?)?.toInt() ?? seats.length,
      availableCount: (json['availableCount'] as num?)?.toInt() ?? 0,
      rows: _rowsOf(
        seats,
        rowCount: (json['rowCount'] as num?)?.toInt(),
        seatsPerRow: (json['seatPerRow'] as num?)?.toInt(),
      ),
    );
  }

  final int zoneId;
  final String zoneName;
  final int price;
  final int seatCount;
  final int availableCount;

  /// 열 → 자리. 자리가 없는 칸(통로)은 null 이다.
  final List<List<Seat?>> rows;

  /// 좌석을 격자에 꽂는다. 스탠딩처럼 격자 크기를 서버가 비워 주면 좌석이 말하는
  /// 최대 열·번호로 크기를 잡는다.
  static List<List<Seat?>> _rowsOf(
    List<Seat> seats, {
    int? rowCount,
    int? seatsPerRow,
  }) {
    if (seats.isEmpty) return const [];

    final rows = rowCount ?? seats.map((seat) => seat.row).reduce(_max);
    final columns =
        seatsPerRow ?? seats.map((seat) => seat.number).reduce(_max);

    final grid = [
      for (var row = 0; row < rows; row++) List<Seat?>.filled(columns, null),
    ];
    for (final seat in seats) {
      // 격자 밖에 있다고 온 좌석은 버린다. 넣으려면 격자를 늘려야 하는데,
      // 그러면 화면이 서버가 알려 준 배치도와 다른 크기로 그려진다.
      if (seat.row < 1 || seat.row > rows) continue;
      if (seat.number < 1 || seat.number > columns) continue;
      grid[seat.row - 1][seat.number - 1] = seat;
    }
    return grid;
  }

  static int _max(int a, int b) => a > b ? a : b;
}
