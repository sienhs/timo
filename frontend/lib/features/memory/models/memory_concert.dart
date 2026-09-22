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
    this.time,
    this.goodsId,
  });

  /// 이 줄의 주 식별자. 소장품 하나가 여기에 붙는다.
  final String ticketId;
  final String id, title, artist, date, venue, poster, videoUrl;

  /// 공연 시작 시각(`19:00`). 서버는 날짜와 시각을 한 값으로 주고, 화면은
  /// 둘을 따로 쓴다. 시각이 없는 줄도 있을 수 있어 선택 항목이다.
  final String? time;

  /// 이 티켓으로 **서버에** 이미 만들어 둔 소장품 번호. 없으면 null.
  ///
  /// 기기 저장소가 아니라 이 값이 "이미 만들었는가" 의 기준이다. 다른 기기에서
  /// 만들었으면 이 기기 저장소는 비어 있지만 티켓에는 이미 소장품이 붙어 있어,
  /// 저장소만 보고 판단하면 만들기로 들어갔다가 서버가 409 로 막는다.
  final String? goodsId;

  String get videoId => '$id-main';

  /// 티켓 뒷면에 인쇄할 사실들.
  ///
  /// 좌석·예매 번호는 없다. 카탈로그 API 가 주지 않고 서버의 소장품 스냅샷도
  /// 공연명·아티스트·날짜·장소만 담는다 — 여기서 지어내면 이 기기에서 만든
  /// 소장품과 서버에서 복원한 소장품의 뒷면이 서로 달라진다.
  Map<String, String> get ticketDetails => {
    '공연명': title,
    '아티스트': artist,
    '날짜': date,
    '시간': ?time,
    '장소': venue,
  };
}
