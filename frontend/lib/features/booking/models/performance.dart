/// 예매 대상 공연. 요구사항상 단일 회차 · 좌석 지정 공연만 다루므로
/// 회차(round) 개념은 두지 않는다.
///
/// 공연 상세(`ShowDetail`)와 필드가 겹치지만 합치지 않는다. 저쪽은 공연을
/// 소개하는 데 필요한 것(가격표·아티스트·예매 상태)을 들고 있고, 이쪽은 예매
/// 중에 화면 위쪽에 계속 떠 있어야 하는 것만 들고 있다. 상세를 통째로 들고
/// 다니면 예매 화면이 쓰지도 않는 값에 묶인다.
class Performance {
  const Performance({
    required this.title,
    required this.venue,
    required this.startAt,
    this.posterUrl,
    required this.bookingFee,
  });

  final String title;
  final String venue;
  final DateTime startAt;

  /// 공연 포스터 주소. 포스터가 없는 공연이면 null 이다.
  /// 결제 화면이 포스터를 그리므로 여기에 함께 둔다.
  final String? posterUrl;

  /// 예매 수수료. 시안에는 3,000원으로 있으나 요구사항 문서에는 수수료 개념이
  /// 없다. 온체인에 기록되는 '정가'에 포함되는지 여부가 양도 상한 판정에
  /// 영향을 주므로 기획 확정 전까지는 정가와 분리해 둔다.
  final int bookingFee;
}
