import 'package:flutter/material.dart';

import '../../../core/widgets/async_boundary.dart';
import '../../../core/widgets/timo_mascot.dart';
import '../../../routes/app_routes.dart';
import '../../auth/constants.dart';
import '../../auth/state/auth_session_scope.dart';
import '../constants.dart';
import '../models/collection_slot.dart';
import '../models/memory_concert.dart';
import '../models/memory_ticket.dart';
import '../state/memory_concert_api_scope.dart';
import '../state/ticket_store_scope.dart';
import '../widgets/collection/collection_view.dart';
import '../widgets/ui/glow_button.dart';
import '../motion/reveal.dart';
import '../theme/timo_colors.dart';
import 'creator_screen.dart';
import 'memory_page_route.dart';
import 'memory_ticket_screen.dart';

/// 소장품(메모리 티켓) 목록. 빠른 메뉴의 '컬렉션' 으로 들어온다.
///
/// 공연 카탈로그는 서버에서, 만든 소장품은 기기 저장소에서 와서 여기서 한
/// 목록으로 합쳐진다. [CollectionView] 는 합쳐진 결과만 그린다 — 화면이
/// 저장소도 API 도 모르게 두는 것이 이 화면의 일이다.
///
/// **로그인해야 들어온다.** 카탈로그가 "내가 입장을 마친 티켓" 이라 누구인지
/// 모르면 물어볼 것이 없다(찜·충전·양도마켓과 같은 방식).
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  /// 로그인한 동안에만 있다.
  Future<List<MemoryConcert>>? _concerts;

  bool get _isLoggedIn =>
      AuthSessionScope.maybeOf(context)?.isLoggedIn ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 로그인한 채로 들어왔거나 여기서 로그인하고 돌아왔을 때 받아 온다.
    // 로그아웃되면 들고 있던 것을 버린다.
    if (_isLoggedIn) {
      _concerts ??= _loadConcerts();
    } else {
      _concerts = null;
    }
  }

  Future<List<MemoryConcert>> _loadConcerts() =>
      MemoryConcertApiScope.of(context).getConcerts();

  void _reloadConcerts() => setState(() => _concerts = _loadConcerts());

  /// 소장품은 저장된 그대로 연다. 다시 렌더링하거나 저장하지 않는다.
  ///
  /// 삭제는 없다 — 확정한 소장품은 서버에도 수정·삭제가 없고, 확정 전 임시본은
  /// 같은 티켓으로 다시 만들면 덮어쓴다. 그 '다시 만들기' 가 어느 공연인지는
  /// 카탈로그를 든 이 화면만 알아서, 길을 만들어 넘긴다.
  Future<void> _openTicket(MemoryTicket ticket, List<MemoryConcert> concerts) {
    final concert = concerts
        .where((c) => c.ticketId == ticket.ticketId)
        .firstOrNull;
    return Navigator.push(
      context,
      stageRoute<void>(
        MemoryTicketScreen(
          ticket: ticket,
          onEdit: ticket.confirmed || concert == null
              ? null
              // 소장품 화면을 만들기 화면으로 바꾼다. 뒤로 가면 소장품이 아니라
              // 컬렉션으로 돌아오는 것이 자연스럽다.
              : (viewer) => Navigator.pushReplacement(
                  viewer,
                  memoryRoute<void>(CreatorScreen(initialConcert: concert)),
                ),
        ),
      ),
    );
  }

  /// 카탈로그의 티켓 한 장이 칸 하나. 그 티켓으로 만든 소장품을 달고 있다.
  ///
  /// 티켓 번호로 맞춘다. 공연으로 묶으면 같은 공연을 두 번 간 사람의 두 칸이
  /// 같은 소장품을 함께 달게 된다.
  List<CollectionSlot> _buildSlots(
    List<MemoryConcert> concerts,
    List<MemoryTicket> tickets,
  ) {
    final byTicket = {for (final t in tickets) t.ticketId: t};
    return [
      for (final concert in concerts)
        CollectionSlot(
          ticketId: concert.ticketId,
          concertId: concert.id,
          title: concert.title,
          artist: concert.artist,
          date: concert.date,
          poster: concert.poster,
          ticket: byTicket[concert.ticketId],
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final concerts = _concerts;
    if (concerts == null) return const _LoginRequired();
    // 저장소는 이미 최신순으로 준다(캐러셀의 첫 카드).
    final tickets = TicketStoreScope.of(context).readAll();
    return AsyncBoundary<List<MemoryConcert>>(
      future: concerts,
      onRetry: _reloadConcerts,
      builder: (context, concerts) => CollectionView(
        slots: _buildSlots(concerts, tickets),
        tickets: tickets,
        onCreate: () =>
            Navigator.push(context, memoryRoute<void>(const CreatorScreen())),
        onCreateFor: (slot) => Navigator.push(
          context,
          memoryRoute<void>(
            CreatorScreen(
              initialConcert: concerts.firstWhere(
                (c) => c.ticketId == slot.ticketId,
              ),
            ),
          ),
        ),
        onOpen: (ticket) => _openTicket(ticket, concerts),
      ),
    );
  }
}

/// 로그인 전 컬렉션. 빈 목록과 같은 자리에 같은 마스코트를 세우고, 할 수 있는
/// 일만 하나 남긴다.
class _LoginRequired extends StatelessWidget {
  const _LoginRequired();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(CollectionText.title)),
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CollectionLayout.pagePadding * 2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Reveal(child: TimoMascot.sad(size: 150)),
              const SizedBox(height: 28),
              const Reveal(
                index: 1,
                child: Text(
                  CollectionText.loginTitle,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: TimoColors.ink,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Reveal(
                index: 2,
                child: Text(
                  CollectionText.loginBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: TimoColors.inkSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Reveal(
                index: 3,
                child: GlowButton(
                  label: AuthStrings.login,
                  icon: Icons.login_rounded,
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.login),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
