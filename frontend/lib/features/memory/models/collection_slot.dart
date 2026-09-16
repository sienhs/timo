import 'memory_ticket.dart';

/// One catalogue cell: a concert plus whatever tickets the user made for it.
/// Built by the route so the widgets never see the concert repository.
class CollectionSlot {
  const CollectionSlot({
    required this.concertId,
    required this.title,
    required this.artist,
    required this.date,
    required this.poster,
    this.tickets = const [],
  });
  final String concertId, title, artist, date, poster;

  /// Newest first.
  final List<MemoryTicket> tickets;
  bool get owned => tickets.isNotEmpty;
  MemoryTicket? get latest => tickets.isEmpty ? null : tickets.first;
}
