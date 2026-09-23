import 'listing.dart';
import 'listing_status.dart';
import 'wire_time.dart';

/// 매물 한 건의 상세. 서버 `ListingDetailResponseDto` 다. 등록 응답도 같은 모양이다.
/// 목록 항목([Listing])에 공연 정보와 [status] · [closedAt] 이 더해진 것이고,
/// 담기지 않는 값의 기준은 목록과 같다.
class ListingDetail {
  const ListingDetail({
    required this.listingId,
    required this.status,
    required this.concertId,
    required this.concertTitle,
    required this.venueName,
    required this.sectionName,
    required this.price,
    required this.faceValue,
    required this.discountRate,
    required this.mine,
    required this.listedAt,
    this.posterImageUrl,
    this.startAt,
    this.closedAt,
    this.seatRow,
    this.seatNumber,
  });

  factory ListingDetail.fromJson(Map<String, dynamic> json) => ListingDetail(
    listingId: (json['listingId'] as num).toInt(),
    status: ListingStatus.fromWire(json['status']),
    concertId: (json['concertId'] as num).toInt(),
    concertTitle: json['concertTitle'] as String,
    venueName: json['venueName'] as String,
    sectionName: json['sectionName'] as String,
    price: (json['price'] as num).toInt(),
    faceValue: (json['faceValue'] as num).toInt(),
    discountRate: (json['discountRate'] as num).toInt(),
    mine: json['mine'] as bool? ?? false,
    listedAt: DateTime.parse(json['listedAt'] as String),
    posterImageUrl: json['posterImageUrl'] as String?,
    startAt: dateTimeOrNull(json['startDate']),
    closedAt: dateTimeOrNull(json['closedAt']),
    seatRow: (json['seatNo'] as num?)?.toInt(),
    seatNumber: (json['seatCol'] as num?)?.toInt(),
  );

  final int listingId;

  /// 지금 살 수 있는지. 팔렸거나 취소된 매물도 이 응답으로 조회된다.
  final ListingStatus status;

  final int concertId;
  final String concertTitle;
  final String venueName;

  /// 구역 이름. 좌석 열·번호는 서버가 주면 담는다([Listing] 주석).
  final String sectionName;
  final int? seatRow;
  final int? seatNumber;

  final int price;
  final int faceValue;
  final int discountRate;

  /// 내가 올린 매물인가.
  final bool mine;

  final DateTime listedAt;

  final String? posterImageUrl;

  /// 공연 시작 일시. 아직 정해지지 않았으면 null.
  final DateTime? startAt;

  /// 팔리거나 내려간 시각. 아직 올라 있으면 null.
  final DateTime? closedAt;

  /// 정가에서 깎인 금액.
  int get discountAmount => faceValue - price;

  /// 카드에 찍는 좌석. 좌석이 오면 `S구역 8열 19번`, 아니면 구역명만.
  String get seatLabel => formatSeatLabel(sectionName, seatRow, seatNumber);

  /// 지금 이 화면에서 결제까지 갈 수 있는가. 내 매물은 서버도 409 로 막지만
  /// (`CannotBuyOwnListingException`) 버튼을 잠그고 이유를 적는 쪽이 낫다.
  bool get canPurchase => status.isBuyable && !mine;
}
