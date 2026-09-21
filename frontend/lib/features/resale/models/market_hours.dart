import '../../../core/utils/formatters.dart';

/// 양도 마켓 운영 상태. 서버 `GET /market/hours` 응답(`MarketHoursResponseDto`)
/// 한 건이다.
///
/// **열려 있는지는 서버가 판정한다.** 앱이 기기 시계로 판정하면 시간대가 다른
/// 기기(UTC 로 도는 에뮬레이터, 해외 기기)에서 오픈 시각이 어긋나고, 기기
/// 시계를 돌리면 뚫린다. 이 값으로 화면을 잠그는 것은 안내일 뿐이고, 실제
/// 차단은 등록·가격 수정·구매 요청이 각자 409 로 받는다(백엔드 `MarketApi`
/// 주석).
///
/// **남은 시간도 서버 시계로 센다.** 응답의 [serverTime] 과 그 응답을 받은
/// 기기 시각 [receivedAt] 을 함께 들고, 이후 기기 시계가 흐른 만큼을 서버
/// 시각에 더한다([serverNow]). 기기 시계가 몇 분 틀려 있어도 카운트다운은
/// 서버가 닫는 순간에 0 이 된다.
///
/// [opensAt] · [closesAt] 는 규칙(매일 08:00~23:00)이 아니라 구체적인
/// 일시다. 열려 있으면 이번 창, 닫혀 있으면 다음 창의 시각이라 "닫힘까지" 와
/// "오픈까지" 를 같은 값([nextBoundary])으로 센다.
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
  ///
  /// [closesAt] 은 마지막으로 열려 있는 초라 닫히는 순간은 그 1초 뒤다.
  /// [closesAt] 까지 세면 닫는 시각 정각에 0 이 되고, 그때 서버에 다시 물으면
  /// 아직 열려 있다고 답해 화면이 열림 상태에 그대로 머문다.
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

  /// [listedAt] 에 등록된 매물이 남에게 처음 보이는 시각. 등록 다음 날의 여는
  /// 시각이다. 서버 `MarketHoursService.visibleFrom()` 과 같다.
  ///
  /// 내 거래 내역 응답에는 이 값이 없어 앱이 등록 시각에서 계산한다. 여는
  /// 시각의 시:분은 서버가 준 [opensAt] 에서 가져온다 — 규칙을 앱에 박지 않는다.
  DateTime visibleFrom(DateTime listedAt) => DateTime(
    listedAt.year,
    listedAt.month,
    listedAt.day + 1,
    opensAt.hour,
    opensAt.minute,
    opensAt.second,
  );

  /// [listedAt] 에 등록된 매물이 기기 시각 [deviceNow] 에 남에게 보이는 상태인가.
  ///
  /// 서버는 "오늘 00:00 이전에 등록된 매물" 만 목록에 낸다
  /// (`MarketHoursService.visibleBefore()`). 마켓이 닫혀 있어 지금 당장 목록이
  /// 안 열리는 것은 모든 매물에 같이 걸리는 일이라 여기서 보지 않는다 — 이 값은
  /// "이 매물만 아직 안 올라갔는가" 를 가른다. 오늘은 서버 시계 기준이다.
  bool isListingVisible(DateTime listedAt, DateTime deviceNow) {
    final today = serverNow(deviceNow);
    return listedAt.isBefore(DateTime(today.year, today.month, today.day));
  }
}
