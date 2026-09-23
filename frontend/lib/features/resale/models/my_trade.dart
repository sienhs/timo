import 'listing.dart';
import 'wire_time.dart';

/// 내 거래 내역 항목의 종류. 서버 `MyTradeType` 과 값이 같다.
enum MyTradeType {
  /// 내가 올린 매물.
  sale('SALE'),

  /// 내가 산 양도 티켓.
  purchase('PURCHASE'),

  /// 서버가 준 값을 앱이 모른다. 서버에 종류가 하나 늘었을 때만 나온다.
  unknown('');

  const MyTradeType(this.wireName);

  final String wireName;

  static MyTradeType fromWire(Object? value) => values.firstWhere(
    (type) => type.wireName == value,
    orElse: () => unknown,
  );
}

/// 내 거래 내역 항목의 상태. 서버 `MyTradeStatus` 와 값이 같다. 매물 상태와
/// 체결 상태를 합친 응답 전용 값이라 판매에는 [listed] · [sold] · [canceled]
/// 만, 구매에는 [pending] · [confirmed] · [failed] 만 온다.
enum MyTradeStatus {
  /// (판매) 마켓에 올라가 있다. 아직 안 팔렸다.
  listed('LISTED'),

  /// (판매) 팔렸다.
  sold('SOLD'),

  /// (판매) 내가 등록을 취소했다.
  canceled('CANCELED'),

  /// (구매) DB 체결은 끝났고 온체인 전송이 남았다.
  pending('PENDING'),

  /// (구매) 온체인 전송까지 끝났다.
  confirmed('CONFIRMED'),

  /// (구매) 온체인 전송이 실패했다.
  failed('FAILED'),

  /// 서버가 준 값을 앱이 모른다. 올라가 있는 매물로 치지 않는다 — 모르는
  /// 상태에 취소 버튼을 열어 주면 서버가 거절할 요청을 먼저 시도하게 된다.
  unknown('');

  const MyTradeStatus(this.wireName);

  final String wireName;

  static MyTradeStatus fromWire(Object? value) => values.firstWhere(
    (status) => status.wireName == value,
    orElse: () => unknown,
  );
}

/// 내 거래 내역의 항목 하나. 서버 `MyTradeSummaryResponseDto` 한 건이다.
/// 판매와 구매가 같은 모양으로 한 목록에 섞여 오고(`GET /market/listings/me`),
/// 내 티켓의 양도 목록 탭은 이 중 판매([isSale])만 그린다. 거래 상대 ·
/// `ticketId` · `tokenId` 는 없어 예매 목록의 티켓과 이어 붙일 수 없다.
class MyTrade {
  const MyTrade({
    required this.type,
    required this.listingId,
    required this.status,
    required this.concertId,
    required this.concertTitle,
    required this.venueName,
    required this.sectionName,
    required this.seatRow,
    required this.seatNumber,
    required this.price,
    required this.faceValue,
    required this.occurredAt,
    this.tradeId,
    this.posterImageUrl,
    this.startAt,
  });

  factory MyTrade.fromJson(Map<String, dynamic> json) => MyTrade(
    type: MyTradeType.fromWire(json['type']),
    tradeId: (json['tradeId'] as num?)?.toInt(),
    listingId: (json['listingId'] as num).toInt(),
    status: MyTradeStatus.fromWire(json['status']),
    concertId: (json['concertId'] as num).toInt(),
    concertTitle: json['concertTitle'] as String,
    venueName: json['venueName'] as String,
    sectionName: json['sectionName'] as String,
    // 예매 응답과 같은 이름이다. `seatNo` 가 행(열), `seatCol` 이 자리.
    seatRow: (json['seatNo'] as num).toInt(),
    seatNumber: (json['seatCol'] as num).toInt(),
    price: (json['price'] as num).toInt(),
    faceValue: (json['faceValue'] as num).toInt(),
    occurredAt: DateTime.parse(json['occurredAt'] as String),
    posterImageUrl: json['posterImageUrl'] as String?,
    startAt: dateTimeOrNull(json['startDate']),
  );

  final MyTradeType type;

  /// 체결 번호. 구매에만 있다. 판매는 팔리지 않았을 수 있어 체결이 없고,
  /// 팔렸어도 상태가 [MyTradeStatus.sold] 로 바뀔 뿐 이 값은 오지 않는다.
  final int? tradeId;

  /// 매물 번호. 등록 취소가 이 값으로 간다.
  final int listingId;

  final MyTradeStatus status;

  final int concertId;
  final String concertTitle;
  final String venueName;

  /// 구역 이름. (예: `R석`)
  final String sectionName;

  /// 구역 안에서의 행 번호와 그 행 안의 자리 번호. 내 거래라 늘 온다 —
  /// 매물 목록([Listing])처럼 남의 좌석을 숨길 이유가 없다.
  final int seatRow;
  final int seatNumber;

  /// 판매면 내가 매긴 등록가, 구매면 실제로 결제한 금액(원).
  final int price;

  /// 예매 시점의 정가(원). 등록가의 상한이다.
  final int faceValue;

  /// 판매면 등록 시각, 구매면 체결 시각. 두 종류를 한 목록으로 늘어놓는
  /// 정렬 기준이라 이름이 하나다.
  final DateTime occurredAt;

  final String? posterImageUrl;

  /// 공연 시작 일시. 아직 정해지지 않았으면 null.
  final DateTime? startAt;

  /// 내가 올린 매물인가.
  bool get isSale => type == MyTradeType.sale;

  /// 지금 마켓에 올라가 있는 매물인가. 양도 목록 탭의 개수와 등록 취소 버튼이
  /// 이 값을 본다. 팔렸거나 내린 것은 "지금 올라가 있는 매물" 이 아니다.
  bool get isOnSale => isSale && status == MyTradeStatus.listed;

  /// 카드에 찍는 좌석. (예: `R석 12열 24번`)
  String get seatLabel => formatSeatLabel(sectionName, seatRow, seatNumber);

  /// 양도 마감(공연 시작)까지 남은 시간. 응답에 마감 시각이 따로 없다 — 상세의
  /// `closedAt` 은 팔리거나 내려간 시각이지 마감이 아니다. 날짜가 미정이거나
  /// 이미 지났으면 null 이라 화면이 카운트다운을 그리지 않는다.
  Duration? remaining(DateTime now) {
    final start = startAt;
    if (start == null || !start.isAfter(now)) return null;
    return start.difference(now);
  }
}
