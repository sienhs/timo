/// 매물 목록의 항목 하나. 서버 `ListingSummaryResponseDto` 한 건이다.
/// 좌석번호는 선택값이라 서버가 `seatNo` · `seatCol` 을 실어 주면 찍고 없으면
/// 구역명만 찍는다([seatLabel]). 판매자를 가리키는 값 · `ticketId` · `tokenId`
/// · 공연 정보는 없다 — 공연은 화면이 고른 공연에서 가져온다.
class Listing {
  const Listing({
    required this.listingId,
    required this.sectionName,
    required this.price,
    required this.faceValue,
    required this.discountRate,
    required this.mine,
    required this.listedAt,
    this.seatRow,
    this.seatNumber,
  });

  factory Listing.fromJson(Map<String, dynamic> json) => Listing(
    listingId: (json['listingId'] as num).toInt(),
    sectionName: json['sectionName'] as String,
    // 예매 응답과 같은 이름을 기대한다. `seatNo` 가 행(열), `seatCol` 이 자리.
    seatRow: (json['seatNo'] as num?)?.toInt(),
    seatNumber: (json['seatCol'] as num?)?.toInt(),
    price: (json['price'] as num).toInt(),
    faceValue: (json['faceValue'] as num).toInt(),
    discountRate: (json['discountRate'] as num).toInt(),
    mine: json['mine'] as bool? ?? false,
    listedAt: DateTime.parse(json['listedAt'] as String),
  );

  /// 밖으로 나가는 유일한 식별자. 구매·취소가 이 값으로 이뤄진다.
  final int listingId;

  /// 구역 이름. (예: `S구역`)
  final String sectionName;

  /// 구역 안의 행(열) 번호와 그 행 안의 자리 번호. 서버가 주지 않으면 null.
  final int? seatRow;
  final int? seatNumber;

  /// 등록가(원). 정가 이하다.
  final int price;

  /// 예매 시점의 정가(원). 지금의 구역 가격이 아니라 그때 찍힌 값이다.
  final int faceValue;

  /// 정가 대비 할인율(%). 서버가 계산해 준다 — 앱이 다시 계산하면 반올림
  /// 방식이 갈려 목록과 상세의 숫자가 달라진다.
  final int discountRate;

  /// 내가 올린 매물인가. 본인에게만 참이다. 화면은 구매를 막는다.
  final bool mine;

  final DateTime listedAt;

  /// 정가에서 깎인 금액. 구매 확인 화면의 `할인가` 줄이 쓴다.
  int get discountAmount => faceValue - price;

  /// 목록 줄 첫 칸. 좌석이 오면 `S구역 8열 19번`, 아니면 `S구역`.
  String get seatLabel => formatSeatLabel(sectionName, seatRow, seatNumber);
}

/// 구역·열·번호를 한 줄로 잇는다. 열·번호 중 하나라도 없으면 구역명만이다 —
/// `S구역 8열` 처럼 반만 찍으면 그 열 전체를 가리키는 것처럼 읽힌다.
String formatSeatLabel(String sectionName, int? row, int? number) =>
    row == null || number == null ? sectionName : '$sectionName $row열 $number번';
