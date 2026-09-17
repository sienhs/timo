/// 입장 QR 한 장. 서버(`GET /api/v1/tickets/{ticketId}/entry-pass`)가 발급한다.
///
/// [token] 은 서버가 서명한 문자열이다. 앱은 **안을 들여다보지 않고** 그대로
/// QR 로 그린다. 해석을 시작하면 서버가 형식을 바꿀 때마다 앱 배포까지 묶인다.
/// 남은 시간도 토큰에서 뽑지 않고 서버가 따로 준 [lifetime] 으로 센다(백엔드
/// `EntryPassResponseDto` 주석).
///
/// 서버는 만료 **시각**이 아니라 "몇 초 남았는가" 를 준다. 그래서 응답을 받은
/// 시각([receivedAt])을 앱이 찍어 두고 거기서부터 센다. 서버 시계와 기기 시계가
/// 어긋나도 남은 시간은 어긋나지 않는다. 응답이 오는 데 걸린 시간만큼은 실제
/// 만료보다 늦게 0 을 찍지만, 30초 수명에 1초 안쪽이라 눈에 띄지 않는다.
///
/// 이전에는 앱이 스스로 문자열을 만들었다. 규칙만 알면 누구나 같은 값을 만들 수
/// 있어 위조를 막지 못했고, 그래서 30초 회전도 모양만 흉내 낸 것이었다. 서버가
/// 서명하고 게이트가 서명·만료를 확인하게 되면서 그 코드는 지웠다.
class EntryPass {
  const EntryPass({
    required this.token,
    required this.lifetime,
    required this.receivedAt,
  });

  /// 서버 응답(`EntryPassResponseDto`)을 읽는다.
  ///
  /// [receivedAt] 은 응답이 도착한 시각. 응답 안에는 없어 읽는 쪽이 넘긴다.
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

  /// 남은 비율(0~1). 진행 바가 쓴다.
  ///
  /// 수명이 0 인 응답은 서버가 주지 않지만, 나눗셈이라 방어한다.
  double progress(DateTime now) => lifetime == Duration.zero
      ? 0
      : remaining(now).inMilliseconds / lifetime.inMilliseconds;
}
