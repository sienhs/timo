import 'package:flutter/material.dart';

import '../../../core/widgets/async_boundary.dart';
import '../models/collection_slot.dart';
import '../models/memory_concert.dart';
import '../models/memory_ticket.dart';
import '../state/memory_concert_api_scope.dart';
import '../state/ticket_store_scope.dart';
import '../widgets/collection/collection_view.dart';
import '../widgets/ui/overlay_service.dart';
import 'creator_screen.dart';
import 'memory_page_route.dart';
import 'memory_ticket_screen.dart';

/// 소장품(메모리 티켓) 목록. 빠른 메뉴의 '컬렉션' 으로 들어온다.
///
/// 공연 카탈로그는 서버에서, 만든 소장품은 기기 저장소에서 와서 여기서 한
/// 목록으로 합쳐진다. [CollectionView] 는 합쳐진 결과만 그린다 — 화면이
/// 저장소도 API 도 모르게 두는 것이 이 화면의 일이다.
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  late Future<List<MemoryConcert>> _concerts;

  @override
  void initState() {
    super.initState();
    // 스코프는 구독이 아니라 읽기라 initState 에서 꺼내도 된다.
    _concerts = _loadConcerts();
  }

  Future<List<MemoryConcert>> _loadConcerts() =>
      MemoryConcertApiScope.of(context).getConcerts();

  void _reloadConcerts() => setState(() => _concerts = _loadConcerts());

  /// 완성된 소장품은 저장된 그대로 연다. 다시 렌더링하거나 저장하지 않는다.
  Future<void> _openTicket(MemoryTicket ticket) =>
      Navigator.push(context, stageRoute<void>(MemoryTicketScreen(ticket: ticket)));

  Future<void> _confirmAndDelete(MemoryTicket ticket) async {
    final answer = await OverlayService.choose(
      context,
      title: '소장품을 삭제할까요?',
      message: '목록에서 삭제한 소장품은 복원할 수 없어요.',
      choices: const {'cancel': '취소', 'delete': '삭제'},
      destructive: true,
    );
    if (answer != 'delete' || !mounted) return;
    try {
      // 저장소가 알리면 목록이 따라 바뀐다. 여기서 setState 하지 않는 이유다.
      await TicketStoreScope.read(context).delete(ticket.ticketId);
    } catch (_) {
      if (mounted) OverlayService.notify(context, '삭제하지 못했어요. 다시 시도해주세요.');
    }
  }

  /// 카탈로그의 공연 하나가 칸 하나. 그 공연으로 만든 소장품들을 달고 있다.
  List<CollectionSlot> _buildSlots(
    List<MemoryConcert> concerts,
    List<MemoryTicket> tickets,
  ) {
    final byConcert = <String, List<MemoryTicket>>{};
    for (final ticket in tickets) {
      (byConcert[ticket.concertId] ??= []).add(ticket);
    }
    return [
      for (final concert in concerts)
        CollectionSlot(
          concertId: concert.id,
          title: concert.title,
          artist: concert.artist,
          date: concert.date,
          poster: concert.poster,
          tickets: byConcert[concert.id] ?? const [],
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // 저장소는 이미 최신순으로 준다(캐러셀의 첫 카드).
    final tickets = TicketStoreScope.of(context).readAll();
    return AsyncBoundary<List<MemoryConcert>>(
      future: _concerts,
      onRetry: _reloadConcerts,
      builder: (context, concerts) => CollectionView(
        slots: _buildSlots(concerts, tickets),
        tickets: tickets,
        onCreate: () => Navigator.push(
          context,
          memoryRoute<void>(const CreatorScreen()),
        ),
        onCreateFor: (slot) => Navigator.push(
          context,
          memoryRoute<void>(
            CreatorScreen(
              initialConcert: concerts.firstWhere((c) => c.id == slot.concertId),
            ),
          ),
        ),
        onOpen: _openTicket,
        onDelete: _confirmAndDelete,
      ),
    );
  }
}
