import 'dart:math';

/// 입장 QR 한 장. 30초마다 새로 만들어진다.
///
/// **지금은 앱이 만든다.** 서버에 티켓 도메인이 없어 발급해 줄 곳이 없다.
/// 실제로는 서버가 서명한 토큰이어야 한다 — 앱이 만든 문자열은 규칙만 알면
/// 누구나 똑같이 만들 수 있어 위조를 막지 못한다. 서버가 생기면 [issue] 를
/// "서버에서 받아오기" 로 바꾸고 [payload] 에 그 토큰을 담는다. 화면은 그대로다.
///
/// 30초마다 바꾸는 이유는 캡처한 화면으로 입장하지 못하게 하려는 것이다. 그
/// 규칙이 성립하려면 검표기가 발급 시각을 확인해야 하므로, 서버가 붙기 전까지
/// 이 회전은 **모양만 흉내 낸 것**이다.
class EntryPass {
  const EntryPass({required this.payload, required this.issuedAt});

  /// 예매 한 건의 입장권을 만든다.
  factory EntryPass.issue({
    required int reservationId,
    required DateTime now,
    Random? random,
  }) {
    // 초 단위까지만 쓴다. 밀리초는 검표에 쓸모가 없고 QR 만 길어진다.
    final seconds = now.millisecondsSinceEpoch ~/ 1000;
    final nonce = (random ?? _random).nextInt(1 << 32).toRadixString(16);
    return EntryPass(
      payload: 'timo:entry:$reservationId:$seconds:$nonce',
      issuedAt: now,
    );
  }

  /// QR 에 실리는 문자열.
  final String payload;

  final DateTime issuedAt;

  /// 이 입장권이 유효한 시간. 지나면 새로 만든다.
  static const lifetime = Duration(seconds: 30);

  /// [now] 기준으로 남은 시간. 다 됐으면 0 이다.
  Duration remaining(DateTime now) {
    final elapsed = now.difference(issuedAt);
    final left = lifetime - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  /// 남은 비율(0~1). 진행 바가 쓴다.
  double progress(DateTime now) =>
      remaining(now).inMilliseconds / lifetime.inMilliseconds;

  static final _random = Random();
}
