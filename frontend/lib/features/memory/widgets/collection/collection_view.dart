
import 'package:flutter/material.dart';

import '../../../../core/widgets/timo_mascot.dart';
import '../../motion/motion_tokens.dart';
import '../../motion/reveal.dart';
import '../../models/memory_ticket.dart';
import '../../theme/timo_colors.dart';
import '../ui/glow_button.dart';
import '../../constants.dart';
import '../../models/collection_slot.dart';
import 'catalog_grid.dart';
import 'collection_filter.dart';
import 'ticket_orgel.dart';

/// 컬렉션: a catalogue grid of every concert ("모두 보기") or a music-box ring
/// of the tickets the user owns ("내가 가진 티켓만 보기"). Pure display; the
/// route supplies data and handles navigation.
class CollectionView extends StatefulWidget {
  const CollectionView({
    super.key,
    required this.slots,
    required this.tickets,
    required this.onCreate,
    required this.onCreateFor,
    required this.onOpen,
    required this.onDelete,
    this.initialFilter = CollectionFilter.all,
  });

  /// Catalogue cells in display order.
  final List<CollectionSlot> slots;

  /// Owned tickets, newest first.
  final List<MemoryTicket> tickets;
  final VoidCallback onCreate;
  final ValueChanged<CollectionSlot> onCreateFor;
  final ValueChanged<MemoryTicket> onOpen, onDelete;
  final CollectionFilter initialFilter;

  @override
  State<CollectionView> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionView> {
  late CollectionFilter filter = widget.initialFilter;

  Widget body() => switch (filter) {
    CollectionFilter.all => CatalogGrid(
      key: const ValueKey('all'),
      slots: widget.slots,
      onOpen: widget.onOpen,
      onCreateFor: widget.onCreateFor,
      onDelete: widget.onDelete,
    ),
    CollectionFilter.mine when widget.tickets.isEmpty => _EmptyStage(
      key: const ValueKey('empty'),
      onCreate: widget.onCreate,
    ),
    CollectionFilter.mine => TicketOrgel(
      key: const ValueKey('mine'),
      tickets: widget.tickets,
      onOpen: widget.onOpen,
      onDelete: widget.onDelete,
    ),
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      // Back arrow appears by itself when this sits inside a shell route.
      title: const Text(CollectionText.title),
      actions: [
        IconButton(
          tooltip: CollectionText.createTooltip,
          onPressed: widget.onCreate,
          icon: const Icon(Icons.add_rounded, size: 28),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CollectionLayout.pagePadding,
              6,
              CollectionLayout.pagePadding,
              6,
            ),
            child: CollectionFilterBar(
              value: filter,
              onChanged: (value) => setState(() => filter = value),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: Motion.slow,
              switchInCurve: Motion.emphasized,
              switchOutCurve: Motion.standard,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween(begin: 0.97, end: 1.0).animate(animation),
                  child: child,
                ),
              ),
              child: body(),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 아직 만든 소장품이 없을 때: 마스코트와 만들기 버튼.
class _EmptyStage extends StatelessWidget {
  const _EmptyStage({super.key, required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CollectionLayout.pagePadding * 2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 빈 목록 자리에는 앱 공통 마스코트를 쓴다. 회색 티켓 자리표시는
          // 격자의 '아직 없는 소장품' 칸과 생김새가 같아서, 목록이 비었을 때도
          // 칸이 하나 있는 것처럼 읽혔다. 그림 자체로 충분하니 따로 움직이지
          // 않는다.
          const Reveal(child: TimoMascot.sad(size: 150)),
          const SizedBox(height: 28),
          const Reveal(
            index: 1,
            child: Text(
              CollectionText.emptyTitle,
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
              CollectionText.emptyBody,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: TimoColors.inkSecondary),
            ),
          ),
          const SizedBox(height: 26),
          Reveal(
            index: 3,
            child: GlowButton(
              label: CollectionText.createLabel,
              icon: Icons.add_rounded,
              onPressed: onCreate,
            ),
          ),
        ],
      ),
    ),
  );
}
