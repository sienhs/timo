import 'reservation_status.dart';

/// 온체인 티켓 발행이 어디까지 갔는지.
///
/// 서버 주문 상세에는 이 값이 따로 없다. 발행이 끝났으면 `tokenId` 가 채워지고
/// 실패했으면 `failureReason` 이 채워지므로, 둘을 읽어 여기로 정리한다
/// ([ReservationDetail.issueStatus]).
enum TicketIssueStatus {
  /// 주문은 확정됐고 티켓은 아직 체인에 올라가는 중이다.
  issuing,

  /// 티켓이 발행돼 내 것이 됐다.
  issued,

  /// 발행이 실패했다. 결제된 금액은 서버가 환불한다.
  failed,
}

/// 주문 한 건의 상세. 서버 `ReservationDetailResponseDto` 한 건이다.
///
/// 주문을 만든 직후의 응답(201)과 진행 상태 조회 응답이 같은 모양이라 모델도
/// 하나다. 목록 한 건([MyTicket])과 겹치는 필드가 많지만 합치지 않는다 —
/// 이쪽에만 발행 진행 상태(`tokenId` · `failureReason`)가 있고, 목록은 그
/// 값을 주지 않는다.
class ReservationDetail {
  const ReservationDetail({
    required this.reservationId,
    required this.concertId,
    required this.title,
    required this.venueName,
    required this.sectionName,
    required this.seatRow,
    required this.seatNumber,
    required this.facePrice,
    required this.status,
    this.posterImageUrl,
    this.startAt,
    this.tokenId,
    this.failureReason,
  });

  factory ReservationDetail.fromJson(Map<String, dynamic> json) =>
      ReservationDetail(
        reservationId: (json['id'] as num).toInt(),
        concertId: (json['concertId'] as num).toInt(),
        title: json['concertTitle'] as String,
        venueName: json['venueName'] as String,
        sectionName: json['sectionName'] as String,
        // 목록과 같다. `seatNo` 가 행(열) 번호, `seatCol` 이 그 행 안의 자리
        // 번호다(`MyTicket.fromJson` 주석 참고).
        seatRow: (json['seatNo'] as num).toInt(),
        seatNumber: (json['seatCol'] as num).toInt(),
        facePrice: (json['facePrice'] as num).toInt(),
        status: ReservationStatus.fromWire(json['status']),
        posterImageUrl: json['posterImageUrl'] as String?,
        startAt: _dateTimeOrNull(json['startDate']),
        tokenId: json['tokenId'] as String?,
        failureReason: json['failureReason'] as String?,
      );

  /// 예매 id. 진행 상태를 다시 물을 때 쓴다.
  final int reservationId;

  final int concertId;
  final String title;
  final String venueName;

  /// 구역 이름. (예: `A구역`)
  final String sectionName;

  /// 구역 안에서의 행 번호. 화면에는 `열` 로 찍는다.
  final int seatRow;

  /// 행 안에서의 자리 번호. 화면에는 `번` 으로 찍는다.
  final int seatNumber;

  /// 정가(원). 서버가 실제로 차감한 금액이다. 수수료는 없다.
  final int facePrice;

  /// 이 자리를 샀는가. 발행 진행 상태는 [issueStatus] 가 따로 가른다.
  final ReservationStatus status;

  /// 포스터 주소. 포스터가 없는 공연이면 null.
  final String? posterImageUrl;

  /// 공연 시작 일시. 아직 정해지지 않았으면 null.
  final DateTime? startAt;

  /// 발행된 NFT 의 번호. 발행이 끝나기 전에는 null.
  ///
  /// 서버가 문자열로 준다(uint256 이라 int 범위를 넘을 수 있다). 화면에 찍을
  /// 일은 없고 "발행됐는가" 를 가리는 데만 쓴다.
  final String? tokenId;

  /// 발행이 실패한 이유. 실패하지 않았으면 null.
  ///
  /// 서버 내부 사정(컨트랙트 오류 문구 등)이 그대로 들어와 사용자에게 보여줄
  /// 글이 아니다. "실패했는가" 를 가리는 데만 쓴다.
  final String? failureReason;

  /// 카드에 찍는 좌석. (예: `A구역 9열 6번`)
  String get seatLabel => '$sectionName $seatRow열 $seatNumber번';

  /// 발행 진행 상태.
  ///
  /// 실패 사유가 있으면 실패, 토큰이 있으면 완료다. 둘 다 없는데 주문이
  /// 취소돼 있으면 발행이 실패해 서버가 주문을 되돌린 것이니 실패로 본다.
  /// 그 밖은 아직 진행 중이다.
  TicketIssueStatus get issueStatus {
    if (failureReason != null) return TicketIssueStatus.failed;
    if (tokenId != null) return TicketIssueStatus.issued;
    if (status.isVoided) return TicketIssueStatus.failed;
    return TicketIssueStatus.issuing;
  }

  /// 서버는 `LocalDateTime` 을 시간대 없는 ISO 문자열(`2026-10-10T19:00:00`)로
  /// 준다. `DateTime.parse` 는 이를 기기 현지 시각으로 읽는다.
  static DateTime? _dateTimeOrNull(Object? value) =>
      value is String ? DateTime.parse(value) : null;
}
