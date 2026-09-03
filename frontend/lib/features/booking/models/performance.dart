/// 예매 대상 공연. 요구사항상 단일 회차 · 좌석 지정 공연만 다루므로
/// 회차(round) 개념은 두지 않는다.
class Performance {
  const Performance({
    required this.title,
    required this.venue,
    required this.startAt,
    required this.posterAsset,
    required this.bookingFee,
  });

  final String title;
  final String venue;
  final DateTime startAt;

  /// 공연 포스터 이미지 경로. 서버 연동 시 URL 로 바뀐다.
  /// 결제 화면이 포스터를 그리므로 여기에 함께 둔다.
  final String posterAsset;

  /// 예매 수수료. 시안에는 3,000원으로 있으나 요구사항 문서에는 수수료 개념이
  /// 없다. 온체인에 기록되는 '정가'에 포함되는지 여부가 양도 상한 판정에
  /// 영향을 주므로 기획 확정 전까지는 정가와 분리해 둔다.
  final int bookingFee;
}
