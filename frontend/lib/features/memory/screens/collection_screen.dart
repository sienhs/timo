import 'package:flutter/material.dart';

import '../../../core/widgets/async_boundary.dart';
import '../../../core/widgets/timo_mascot.dart';
import '../../../routes/app_routes.dart';
import '../../auth/constants.dart';
import '../../auth/state/auth_session_scope.dart';
import '../constants.dart';
import '../data/goods_failure.dart';
import '../data/goods_restore_service.dart';
import '../data/ticket_store.dart';
import '../models/collection_slot.dart';
import '../models/goods_record.dart';
import '../models/memory_concert.dart';
import '../models/memory_ticket.dart';
import '../state/goods_api_scope.dart';
import '../state/memory_concert_api_scope.dart';
import '../state/ticket_store_scope.dart';
import '../widgets/collection/collection_skeleton.dart';
import '../widgets/collection/collection_view.dart';
import '../widgets/ui/glow_button.dart';
import '../widgets/ui/overlay_service.dart';
import '../motion/reveal.dart';
import '../theme/timo_colors.dart';
import 'creator_screen.dart';
import 'memory_page_route.dart';
import 'memory_ticket_screen.dart';

/// 카탈로그와 서버의 내 소장품 목록. 한 번에 받아 한 화면이 된다.
typedef _Catalog = ({List<MemoryConcert> concerts, List<GoodsSummary> goods});

/// 소장품(메모리 티켓) 목록. 빠른 메뉴의 '컬렉션' 으로 들어온다.
///
/// 세 곳에서 온 것이 여기서 한 목록으로 합쳐진다 — 공연 카탈로그(서버), 내
/// 소장품 목록(서버), 만든 소장품(기기 저장소). [CollectionView] 는 합쳐진
/// 결과만 그린다 — 화면이 저장소도 API 도 모르게 두는 것이 이 화면의 일이다.
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
  Future<_Catalog>? _catalog;

  /// 지금 서버에서 가져오는 중인 소장품 번호들. 같은 것을 두 번 받지 않는다.
  final _restoring = <String>{};

  bool get _isLoggedIn =>
      AuthSessionScope.maybeOf(context)?.isLoggedIn ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 로그인한 채로 들어왔거나 여기서 로그인하고 돌아왔을 때 받아 온다.
    // 로그아웃되면 들고 있던 것을 버린다.
    if (_isLoggedIn) {
      _catalog ??= _loadCatalog();
    } else {
      _catalog = null;
    }
  }

  /// 카탈로그와 내 소장품 목록을 함께 받는다. 둘이 맞물려야 칸이 완성된다 —
  /// 카탈로그는 "이 티켓에 소장품이 있다"(goodsId)만 알고, 카드에 그릴 미리보기와
  /// 공연 정보는 소장품 목록에 있다.
  Future<_Catalog> _loadCatalog() async {
    final store = TicketStoreScope.read(context);
    final (concerts, goods) = await (
      MemoryConcertApiScope.of(context).getConcerts(),
      GoodsApiScope.of(context).fetchMyGoods(),
    ).wait;
    await _dropOrphanDrafts(store, concerts);
    return (concerts: concerts, goods: goods);
  }

  /// 서버가 모르는 소장품을 지운다 — 카탈로그에 없는 티켓의 것으로, 서버 번호
  /// ([MemoryTicket.goodsId])도 없는 것.
  ///
  /// 소장품은 카탈로그의 티켓으로만 만들어지므로, 카탈로그에 없는 티켓의
  /// 소장품이 서버 번호도 없다면 서버에 올라간 적이 없고 올라갈 길도 없다 —
  /// 서버가 그 티켓 번호를 모른다(목 카탈로그 시절에 만든 `ticket-4096` 같은
  /// 것이 여기 해당한다). 남겨 두면 목록에 진짜처럼 서 있다가 확정을 누르면
  /// 서버 오류만 돌려준다. 서버 번호가 있는 것은 서버에 있는 것이라, 카탈로그
  /// 사정이 어떻든 건드리지 않는다.
  Future<void> _dropOrphanDrafts(
    TicketStore store,
    List<MemoryConcert> concerts,
  ) async {
    final known = {for (final c in concerts) c.ticketId};
    for (final ticket in store.readAll()) {
      if (ticket.goodsId == null && !known.contains(ticket.ticketId)) {
        await store.delete(ticket.ticketId);
      }
    }
  }

  void _reloadCatalog() => setState(() => _catalog = _loadCatalog());

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

  /// 서버에만 있는 소장품 하나를 이 기기로 가져와 저장하고, [open] 이면 연다.
  ///
  /// 목록에 들어올 때 전부 받지 않고 누른 것만 받는다. 소장품 하나가 이미지
  /// 여러 장(수 MB)이라, 수십 장을 목록 진입마다 받게 할 수는 없다.
  Future<void> _restore(
    CollectionSlot slot,
    List<MemoryConcert> concerts, {
    bool open = true,
  }) async {
    final remote = slot.remote;
    if (remote == null || _restoring.contains(remote.goodsId)) return;

    final service = GoodsRestoreService(GoodsApiScope.of(context));
    final store = TicketStoreScope.read(context);
    setState(() => _restoring.add(remote.goodsId));
    try {
      final ticket = await service.restore(remote.goodsId);
      await store.save(ticket);
      if (!mounted) return;
      setState(() => _restoring.remove(remote.goodsId));
      if (open) await _openTicket(ticket, concerts);
    } catch (error) {
      if (!mounted) return;
      setState(() => _restoring.remove(remote.goodsId));
      OverlayService.notify(
        context,
        goodsFailureMessage(error, fallback: GoodsText.restoreFailed),
      );
    }
  }

  /// 서버에만 있는 것을 전부, 한 장씩 차례로. 함께 받으면 한 소장품의 이미지
  /// 수십 장이 동시에 열려 느린 회선에서 전부 제한 시간에 걸린다.
  Future<void> _restoreAll(
    List<CollectionSlot> slots,
    List<MemoryConcert> concerts,
  ) async {
    for (final slot in slots) {
      if (!mounted) return;
      if (slot.remoteOnly) await _restore(slot, concerts, open: false);
    }
  }

  /// 카탈로그의 티켓 한 장이 칸 하나. 그 티켓으로 만든 소장품을 달고 있다.
  ///
  /// 티켓 번호로 맞춘다. 공연으로 묶으면 같은 공연을 두 번 간 사람의 두 칸이
  /// 같은 소장품을 함께 달게 된다. 기기에 있으면 그것을, 없는데 서버에 있으면
  /// 서버 것을 단다.
  List<CollectionSlot> _buildSlots(
    _Catalog catalog,
    List<MemoryTicket> tickets,
  ) {
    final byTicket = {for (final t in tickets) t.ticketId: t};
    final remoteByTicket = {for (final g in catalog.goods) g.ticketId: g};
    return [
      for (final concert in catalog.concerts)
        CollectionSlot(
          ticketId: concert.ticketId,
          concertId: concert.id,
          title: concert.title,
          artist: concert.artist,
          date: concert.date,
          poster: concert.poster,
          ticket: byTicket[concert.ticketId],
          remote: byTicket.containsKey(concert.ticketId)
              ? null
              : remoteByTicket[concert.ticketId],
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog;
    if (catalog == null) return const _LoginRequired();
    // 저장소는 이미 최신순으로 준다(캐러셀의 첫 카드).
    final tickets = TicketStoreScope.of(context).readAll();
    return AsyncBoundary<_Catalog>(
      future: catalog,
      onRetry: _reloadCatalog,
      loading: const CollectionSkeleton(),
      builder: (context, catalog) {
        final slots = _buildSlots(catalog, tickets);
        return CollectionView(
          slots: slots,
          tickets: tickets,
          restoring: _restoring,
          onCreate: () =>
              Navigator.push(context, memoryRoute<void>(const CreatorScreen())),
          onCreateFor: (slot) => Navigator.push(
            context,
            memoryRoute<void>(
              CreatorScreen(
                initialConcert: catalog.concerts.firstWhere(
                  (c) => c.ticketId == slot.ticketId,
                ),
              ),
            ),
          ),
          onOpen: (ticket) => _openTicket(ticket, catalog.concerts),
          onRestore: (slot) => _restore(slot, catalog.concerts),
          onRestoreAll: () => _restoreAll(slots, catalog.concerts),
        );
      },
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
