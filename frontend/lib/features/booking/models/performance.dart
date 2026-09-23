/// 예매 대상 공연. 단일 회차 · 좌석 지정 공연만 다루므로 회차 개념은 없다.
/// 공연 상세(`ShowDetail`)와 필드가 겹치지만, 예매 중 화면 위쪽에 계속 떠 있어야
/// 하는 것만 들고 있어 합치지 않는다. 예매 수수료는 없다 — 서버가 구역 정가만
/// 차감하고 환불도 정가 전액이다.
class Performance {
  const Performance({
    required this.title,
    required this.venue,
    required this.startAt,
    this.posterUrl,
  });

  final String title;
  final String venue;
  final DateTime startAt;

  /// 공연 포스터 주소. 포스터가 없는 공연이면 null 이다.
  /// 결제 화면이 포스터를 그리므로 여기에 함께 둔다.
  final String? posterUrl;
}
