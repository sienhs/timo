import 'listing.dart';
import 'trade_status.dart';
import 'wire_time.dart';

/// 방금 체결된 양도 한 건. 서버 `PurchaseResponseDto` 다. [status] 는 언제나
/// [TradeStatus.confirmed] 다 — 코인 전송과 소유권 이전이 응답 전에 끝난다.
/// 포스터 주소가 없어 구매 화면이 들고 있던 것을 함께 넘긴다([PurchaseResult]).
class PurchasedTrade {
  const PurchasedTrade({
    required this.tradeId,
    required this.listingId,
    required this.status,
    required this.price,
    required this.concertTitle,
    required this.venueName,
    required this.sectionName,
    required this.tradedAt,
    this.startAt,
    this.seatRow,
    this.seatNumber,
  });

  factory PurchasedTrade.fromJson(Map<String, dynamic> json) => PurchasedTrade(
    tradeId: (json['tradeId'] as num).toInt(),
    listingId: (json['listingId'] as num).toInt(),
    status: TradeStatus.fromWire(json['status']),
    price: (json['price'] as num).toInt(),
    concertTitle: json['concertTitle'] as String,
    venueName: json['venueName'] as String,
    sectionName: json['sectionName'] as String,
    tradedAt: DateTime.parse(json['tradedAt'] as String),
    startAt: dateTimeOrNull(json['startDate']),
    seatRow: (json['seatNo'] as num?)?.toInt(),
    seatNumber: (json['seatCol'] as num?)?.toInt(),
  );

  /// 체결 번호. 서버 `ticket_trade` 의 PK 이고, 온체인 `Marketplace.buy` 가
  /// 받는 `tradeId`(bytes32)와는 다른 값이다.
  final int tradeId;

  final int listingId;
  final TradeStatus status;

  /// 실제로 결제된 금액(원).
  final int price;

  final String concertTitle;
  final String venueName;
  final String sectionName;
  final DateTime tradedAt;
  final DateTime? startAt;

  /// 좌석 열·번호. 체결 응답에는 아직 없어 서버가 실어 주기 전까지 null 이다.
  final int? seatRow;
  final int? seatNumber;

  /// 완료 화면에 찍는 좌석. 좌석이 오면 `S구역 8열 19번`, 아니면 구역명만.
  String get seatLabel => formatSeatLabel(sectionName, seatRow, seatNumber);
}

/// 결제 완료 화면이 받는 것. 체결 결과와, 응답에 없는 포스터 주소. 포스터
/// 때문에 완료 화면이 매물 상세를 다시 부르지 않는다.
class PurchaseResult {
  const PurchaseResult({required this.trade, this.posterImageUrl});

  final PurchasedTrade trade;
  final String? posterImageUrl;
}
