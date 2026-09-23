/// 공연 알림 신청의 종류. 종류마다 따로 신청하고 따로 푼다.
///
/// [serverName] 은 서버 `AlarmType` 의 이름이고 요청 주소에 그대로 들어간다.
enum AlarmType {
  /// 예매 오픈 안내. 예매 오픈 D-7 · D-1 · H-1 에 알린다.
  concertOpen('CONCERT_OPEN'),

  /// 양도 매물 안내. 새 양도 매물이 올라오면 다음 날 마켓 여는 시각에 알린다.
  marketListing('MARKET_LISTING');

  const AlarmType(this.serverName);

  final String serverName;
}

/// 한 공연에 대한 내 알림 신청 상태.
///
/// 공연 상세는 로그인 없이 열려 있어 상세 응답에 이 값이 없다. 그래서 따로 묻는다.
class AlarmStatus {
  const AlarmStatus({this.concertOpen = false, this.marketListing = false});

  /// 서버 `AlarmStatusResponseDto`. 두 값이 빠짐없이 온다.
  factory AlarmStatus.fromJson(Map<String, dynamic> json) => AlarmStatus(
    concertOpen: json['concertOpen'] == true,
    marketListing: json['marketListing'] == true,
  );

  /// 아무것도 신청하지 않은 상태. 로그아웃 상태의 버튼도 이것으로 그린다.
  static const none = AlarmStatus();

  final bool concertOpen;
  final bool marketListing;

  bool isOn(AlarmType type) => switch (type) {
    AlarmType.concertOpen => concertOpen,
    AlarmType.marketListing => marketListing,
  };

  /// [type] 만 [on] 으로 바꾼 상태. 다른 종류는 그대로다.
  AlarmStatus copyWith(AlarmType type, {required bool on}) => AlarmStatus(
    concertOpen: type == AlarmType.concertOpen ? on : concertOpen,
    marketListing: type == AlarmType.marketListing ? on : marketListing,
  );

  @override
  bool operator ==(Object other) =>
      other is AlarmStatus &&
      other.concertOpen == concertOpen &&
      other.marketListing == marketListing;

  @override
  int get hashCode => Object.hash(concertOpen, marketListing);

  @override
  String toString() =>
      'AlarmStatus(concertOpen: $concertOpen, marketListing: $marketListing)';
}
