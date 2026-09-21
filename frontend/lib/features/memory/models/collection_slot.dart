import 'memory_ticket.dart';

/// 카탈로그 칸 하나 = 입장을 마친 내 티켓 한 장과, 그 티켓으로 만든 소장품.
///
/// 소장품은 있거나 없거나 둘 중 하나다. 티켓 한 장에 소장품은 한 개까지이기
/// 때문이다(백엔드 `uk_goods_ticket`). 칸을 만드는 일은 화면이 하므로 위젯은
/// 저장소도 API 도 보지 않는다.
class CollectionSlot {
  const CollectionSlot({
    required this.ticketId,
    required this.concertId,
    required this.title,
    required this.artist,
    required this.date,
    required this.poster,
    this.ticket,
  });
  final String ticketId, concertId, title, artist, date, poster;

  /// 이 티켓으로 만든 소장품. 아직 만들지 않았으면 null.
  final MemoryTicket? ticket;
  bool get owned => ticket != null;
}
