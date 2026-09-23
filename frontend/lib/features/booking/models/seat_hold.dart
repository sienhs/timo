import '../constants.dart';

/// 좌석을 잡아 둔 결과. 서버 선점 응답 한 건이다.
class SeatHold {
  const SeatHold({
    required this.seatId,
    required this.price,
    required this.expiresAt,
    required this.heldAt,
    this.releasedSeatId,
  });

  /// @param now 응답을 받은 시각. 남은 시간을 세는 기준점이다.
  factory SeatHold.fromJson(Map<String, dynamic> json, {DateTime? now}) =>
      SeatHold(
        seatId: (json['seatId'] as num).toInt(),
        price: (json['price'] as num).toInt(),
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        heldAt: now ?? DateTime.now(),
        releasedSeatId: (json['releasedSeatId'] as num?)?.toInt(),
      );

  final int seatId;

  /// 잡은 자리의 값. 결제 화면이 보여 줄 금액이다. 구역 가격을 화면 사이로 들고
  /// 다니면 구역을 바꿔 다시 잡았을 때 어긋날 수 있어 선점 응답에서 받는다.
  final int price;

  /// 서버가 이 자리를 푸는 시각. 남은 시간을 이 값에서 빼지 않는다 — 서버는
  /// 시간대 없는 시각을 주고 기기는 제 타임존으로 읽어, 타임존이 다르면 그 차이가
  /// 남은 시간에 그대로 들어간다. 남은 시간은 [remainingFrom] 이 센다.
  final DateTime expiresAt;

  /// 앱이 선점 응답을 받은 시각. 기기 시계로 잰다.
  final DateTime heldAt;

  /// 이번 선점 때문에 함께 풀린 이전 자리. 없으면 null. 한 계정은 한 공연에서
  /// 한 자리만 잡을 수 있어, 배치도가 그 자리를 다시 예매 가능으로 되돌린다.
  final int? releasedSeatId;

  /// [now] 기준 남은 시간. 이미 지났으면 [Duration.zero]. 잡은 뒤 얼마나 지났는지만
  /// 기기 시계로 재서 규약 시간(5분)에서 빼므로 서버와 시각이 어긋나도 맞는다.
  Duration remainingFrom(DateTime now) {
    final remaining = BookingConstants.holdDuration - now.difference(heldAt);
    return remaining.isNegative ? Duration.zero : remaining;
  }
}
