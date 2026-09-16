class MemoryConcert {
  const MemoryConcert({
    required this.id,
    required this.title,
    required this.artist,
    required this.date,
    required this.venue,
    required this.poster,
    required this.videoUrl,
  });
  final String id, title, artist, date, venue, poster, videoUrl;
  String get videoId => '$id-main';
  Map<String, String> get ticketDetails => {
    '공연명': title,
    '아티스트': artist,
    '날짜': date,
    '시간': '19:00',
    '장소': venue,
    '게이트': 'GATE 2',
    '좌석': '스탠딩 A · 024',
    '예매 번호': 'DEMO-1024',
    '입장 안내': '소장용 데모 티켓입니다. 실제 입장에 사용할 수 없어요.',
  };
}
