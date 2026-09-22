import 'goods_record.dart';
import 'memory_ticket.dart';

/// 카탈로그 칸 하나 = 입장을 마친 내 티켓 한 장과, 그 티켓으로 만든 소장품.
///
/// 소장품은 셋 중 하나다 — 없거나([ticket]·[remote] 둘 다 null), 이 기기에
/// 있거나([ticket]), 서버에만 있거나([remote]). 티켓 한 장에 소장품은 한 개까지이기
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
    this.remote,
  });
  final String ticketId, concertId, title, artist, date, poster;

  /// 이 기기에 있는 소장품. 없으면 null.
  final MemoryTicket? ticket;

  /// 서버에는 있는데 이 기기에는 없는 소장품(다른 기기에서 만들었다). 가져오면
  /// [ticket] 이 되고 이 값은 쓰이지 않는다.
  final GoodsSummary? remote;

  bool get owned => ticket != null;

  /// 서버에서 가져와야 볼 수 있는 칸.
  bool get remoteOnly => ticket == null && remote != null;
}
