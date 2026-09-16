/// 양도 매물의 상태. 서버 `ListingStatus` 와 값이 같다.
///
/// 상세 조회는 팔린 매물·취소된 매물도 200 으로 준다. 목록에서 상세로 들어가는
/// 사이에 팔릴 수 있고 그때 404 를 주면 화면이 "없는 매물"로 오해하기 때문이다
/// (백엔드 `MarketApi#findListing` 주석). 그래서 **살 수 있는지는 이 값으로만
/// 판단한다.**
enum ListingStatus {
  /// 구매 가능. 매물 목록에 나오는 유일한 상태다.
  listed('LISTED'),

  /// 이미 팔렸다.
  sold('SOLD'),

  /// 판매자가 등록을 취소했다.
  canceled('CANCELED'),

  /// 서버가 준 값을 앱이 모른다. 서버에 상태가 하나 늘었을 때만 나온다.
  ///
  /// 살 수 있다고 넘겨짚지 않는다. 모르는 상태에서 결제를 열어 주면 서버가
  /// 거절할 결제를 사용자가 먼저 시도하게 된다.
  unknown('');

  const ListingStatus(this.wireName);

  final String wireName;

  static ListingStatus fromWire(Object? value) => values.firstWhere(
    (status) => status.wireName == value,
    orElse: () => unknown,
  );

  bool get isBuyable => this == listed;
}
