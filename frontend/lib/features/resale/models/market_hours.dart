import '../../../core/utils/formatters.dart';

/// 양도 마켓 운영 상태. 서버 `GET /market/hours` 응답 한 건이다. 열려 있는지는
/// 서버가 판정하고 이 값은 안내일 뿐이다 — 실제 차단은 각 요청이 409 로 한다.
/// 남은 시간도 서버 시계로 센다([serverNow]). [opensAt] · [closesAt] 는 열려
/// 있으면 이번 창, 닫혀 있으면 다음 창의 구체적인 일시다([nextBoundary]).
class MarketHours {
  const MarketHours({
    required this.isOpen,
    required this.serverTime,
    required this.opensAt,
    required this.closesAt,
    required this.receivedAt,
  });

  /// [receivedAt] 은 응답을 받은 기기 시각이다. 서버 응답에는 없는 값이라
  /// 요청을 보낸 쪽이 넣는다.
  factory MarketHours.fromJson(
    Map<String, dynamic> json, {
    required DateTime receivedAt,
  }) => MarketHours(
    isOpen: json['open'] as bool,
    serverTime: DateTime.parse(json['serverTime'] as String),
    opensAt: DateTime.parse(json['opensAt'] as String),
    closesAt: DateTime.parse(json['closesAt'] as String),
    receivedAt: receivedAt,
  );

  /// 지금 열려 있는가.
  final bool isOpen;

  /// 서버가 판정에 쓴 시각. 초 단위다.
  final DateTime serverTime;

  /// 열려 있으면 이번 창이 열린 시각, 닫혀 있으면 다음에 여는 시각.
  final DateTime opensAt;

  /// 열려 있으면 이번 창이 닫히는 시각, 닫혀 있으면 다음 창이 닫히는 시각.
  /// **포함**이다 — 이 시각 정각까지는 열려 있다(서버 `!now.isAfter(closesAt)`).
  final DateTime closesAt;

  /// 이 응답을 받은 기기 시각. [serverNow] 의 기준점이다.
  final DateTime receivedAt;

  /// 카운트다운 대상. 열려 있으면 닫히는 순간, 닫혀 있으면 여는 시각.
  /// [closesAt] 은 마지막으로 열려 있는 초라 1초 뒤까지 센다 — 정각에 0 이
  /// 되어 서버에 물으면 아직 열려 있다고 답해 화면이 열림 상태에 머문다.
  DateTime get nextBoundary => isOpen ? closesAt.add(_closeGrace) : opensAt;

  static const _closeGrace = Duration(seconds: 1);

  /// 기기 시각 [deviceNow] 를 서버 시계로 옮긴 값.
  DateTime serverNow(DateTime deviceNow) =>
      serverTime.add(deviceNow.difference(receivedAt));

  /// 기기 시각 [deviceNow] 에 [nextBoundary] 까지 남은 시간. 지났으면 0 이다.
  Duration remainingAt(DateTime deviceNow) {
    final left = nextBoundary.difference(serverNow(deviceNow));
    return left.isNegative ? Duration.zero : left;
  }

  /// 여는 시각을 `08:00` 처럼 적는다. 닫힘 화면의 안내 문구가 쓴다.
  String get opensAtLabel => formatClock(opensAt);
}
