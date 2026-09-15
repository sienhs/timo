import '../constants.dart';

/// 좌석을 잡아 둔 결과. 서버 선점 응답 한 건이다.
class SeatHold {
  const SeatHold({
    required this.seatId,
    required this.expiresAt,
    required this.heldAt,
    this.releasedSeatId,
  });

  /// @param now 응답을 받은 시각. 남은 시간을 세는 기준점이다.
  factory SeatHold.fromJson(Map<String, dynamic> json, {DateTime? now}) =>
      SeatHold(
        seatId: (json['seatId'] as num).toInt(),
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        heldAt: now ?? DateTime.now(),
        releasedSeatId: (json['releasedSeatId'] as num?)?.toInt(),
      );

  final int seatId;

  /// 서버가 이 자리를 푸는 시각.
  ///
  /// **남은 시간을 이 값에서 빼지 않는다.** 서버는 시간대 없는 시각을 주고
  /// 기기는 그것을 제 타임존의 시각으로 읽는다. 그래서 기기 타임존이 서버와
  /// 다르면 그 차이가 그대로 남은 시간에 들어간다(에뮬레이터 타임존이 GMT 라
  /// 한국 시각과 9시간 어긋나 '544분 남음' 이 찍히는 것을 보고 알았다).
  /// 화면에 남은 시간을 세는 일은 [remainingFrom] 이 맡고, 이 값은 서버가
  /// 언제 푸는지 확인할 때만 쓴다.
  final DateTime expiresAt;

  /// 앱이 선점 응답을 받은 시각. 기기 시계로 잰다.
  final DateTime heldAt;

  /// 이번 선점 때문에 함께 풀린 이전 자리. 없으면 null.
  ///
  /// 한 계정은 한 공연에서 한 자리만 잡을 수 있어서, 새 자리를 잡으면 앞서
  /// 잡은 자리가 자동으로 풀린다. 배치도에서 그 자리를 다시 예매 가능으로
  /// 되돌리려면 어디가 풀렸는지 알아야 한다.
  final int? releasedSeatId;

  /// [now] 기준 남은 시간. 이미 지났으면 [Duration.zero].
  ///
  /// 잡은 뒤로 **얼마나 지났는지**만 기기 시계로 재서 규약 시간(5분)에서 뺀다.
  /// 경과 시간은 시계가 맞든 틀리든 같은 속도로 흐르므로, 서버와 시각이 어긋나
  /// 있어도 남은 시간은 맞는다.
  Duration remainingFrom(DateTime now) {
    final remaining = BookingConstants.holdDuration - now.difference(heldAt);
    return remaining.isNegative ? Duration.zero : remaining;
  }
}
