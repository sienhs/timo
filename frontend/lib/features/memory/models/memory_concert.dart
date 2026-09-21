/// 카탈로그 한 줄 = 내가 입장을 마친 티켓 한 장.
///
/// 공연이 아니라 **티켓**이 단위인 이유는 소장품이 티켓에 붙기 때문이다 —
/// 백엔드가 `uk_goods_ticket` 으로 1티켓 1소장품을 못 박고, 생성 API 도
/// 티켓 번호로 받는다. 같은 공연을 두 번 갔으면 줄도 두 개다.
class MemoryConcert {
  const MemoryConcert({
    required this.ticketId,
    required this.id,
    required this.title,
    required this.artist,
    required this.date,
    required this.venue,
    required this.poster,
    required this.videoUrl,
  });

  /// 이 줄의 주 식별자. 소장품 하나가 여기에 붙는다.
  final String ticketId;
  final String id, title, artist, date, venue, poster, videoUrl;
  String get videoId => '$id-main';
  Map<String, String> get ticketDetails => {
    '공연명': title,
    '아티스트': artist,
    '날짜': date,
    '시간': '19:00',
    '장소': venue,
    '좌석': '스탠딩 A · 024',
    '예매 번호': 'DEMO-1024',
  };
}
