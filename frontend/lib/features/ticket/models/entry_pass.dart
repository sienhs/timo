/// 입장 QR 한 장. 서버(`GET /api/v1/tickets/{ticketId}/entry-pass`)가 발급한다.
/// [token] 은 서버가 서명한 문자열이라 앱은 해석하지 않고 그대로 QR 로 그린다.
/// 서버는 만료 시각이 아니라 남은 초([lifetime])를 주므로, 응답을 받은 시각
/// ([receivedAt])을 앱이 찍어 두고 거기서부터 센다 — 시계가 어긋나도 괜찮다.
class EntryPass {
  const EntryPass({
    required this.token,
    required this.lifetime,
    required this.receivedAt,
  });

  /// 서버 응답(`EntryPassResponseDto`)을 읽는다. [receivedAt] 은 응답이 도착한
  /// 시각으로, 응답 안에는 없어 읽는 쪽이 넘긴다.
  factory EntryPass.fromJson(
    Map<String, dynamic> json, {
    required DateTime receivedAt,
  }) => EntryPass(
    token: json['token'] as String,
    lifetime: Duration(seconds: (json['expiresInSeconds'] as num).toInt()),
    receivedAt: receivedAt,
  );

  /// QR 에 그대로 실리는 문자열. 해석하지 않는다.
  final String token;

  /// 서버가 정한 이 입장권의 수명. 지나면 새로 받아야 한다.
  final Duration lifetime;

  /// 응답을 받은 시각. 남은 시간은 여기서부터 센다.
  final DateTime receivedAt;

  /// 이 입장권이 만료되는 시각.
  DateTime get expiresAt => receivedAt.add(lifetime);

  /// [now] 기준으로 남은 시간. 다 됐으면 0 이다.
  Duration remaining(DateTime now) {
    final left = expiresAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// 남은 비율(0~1). 진행 바가 쓴다. 수명 0 인 응답은 없지만 나눗셈이라 방어한다.
  double progress(DateTime now) => lifetime == Duration.zero
      ? 0
      : remaining(now).inMilliseconds / lifetime.inMilliseconds;
}
