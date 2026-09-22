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

/// 컬렉션: a catalogue grid of the concerts the user attended ("모두 보기") or a
/// music-box ring of the collectibles they made ("내가 만든 소장품 보기"). Pure
/// display; the route supplies data and handles navigation.
class CollectionView extends StatefulWidget {
  const CollectionView({
    super.key,
    required this.slots,
    required this.tickets,
    required this.onCreate,
    required this.onCreateFor,
    required this.onOpen,
    this.onRestore,
    this.onRestoreAll,
    this.restoring = const {},
    this.initialFilter = CollectionFilter.mine,
  });

  /// Catalogue cells in display order.
  final List<CollectionSlot> slots;

  /// Owned tickets, newest first.
  final List<MemoryTicket> tickets;
  final VoidCallback onCreate;
  final ValueChanged<CollectionSlot> onCreateFor;
  final ValueChanged<MemoryTicket> onOpen;

  /// 서버에만 있는 칸을 눌렀을 때. 없으면 그런 칸이 없는 화면이다(테스트).
  final ValueChanged<CollectionSlot>? onRestore;

  /// "내가 만든 소장품 보기" 위 안내의 버튼. 서버에만 있는 것을 전부 가져온다.
  final VoidCallback? onRestoreAll;

  /// 지금 가져오는 중인 소장품 번호들.
  final Set<String> restoring;
  final CollectionFilter initialFilter;

  @override
  State<CollectionView> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionView> {
  late CollectionFilter filter = widget.initialFilter;

  /// 서버에는 있는데 이 기기에는 없는 칸들.
  List<CollectionSlot> get pending => [
    for (final slot in widget.slots)
      if (slot.remoteOnly) slot,
  ];

  Widget body() => switch (filter) {
    // 카탈로그가 비면 격자도 비어 아무 말이 없다. 왜 비었는지는 알려 줘야 한다.
    CollectionFilter.all when widget.slots.isEmpty => const _EmptyCatalog(
      key: ValueKey('empty-all'),
    ),
    CollectionFilter.all => CatalogGrid(
      key: const ValueKey('all'),
      slots: widget.slots,
      onOpen: widget.onOpen,
      onCreateFor: widget.onCreateFor,
      onRestore: widget.onRestore ?? (_) {},
      restoring: widget.restoring,
    ),
    CollectionFilter.mine when widget.tickets.isEmpty => _EmptyStage(
      key: const ValueKey('empty'),
      onCreate: widget.onCreate,
    ),
    CollectionFilter.mine => TicketOrgel(
      key: const ValueKey('mine'),
      tickets: widget.tickets,
      onOpen: widget.onOpen,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final remote = pending;
    return Scaffold(
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
            // 내 목록에서만 안내한다. 격자에서는 그 칸 자체가 가져오기 버튼이다.
            if (filter == CollectionFilter.mine &&
                remote.isNotEmpty &&
                widget.onRestoreAll != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CollectionLayout.pagePadding,
                  0,
                  CollectionLayout.pagePadding,
                  6,
                ),
                child: _PendingBanner(
                  count: remote.length,
                  busy: widget.restoring.isNotEmpty,
                  onRestoreAll: widget.onRestoreAll!,
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
}

/// 다른 기기에서 만든 소장품이 서버에 있을 때의 한 줄 안내와 가져오기 버튼.
class _PendingBanner extends StatelessWidget {
  const _PendingBanner({
    required this.count,
    required this.busy,
    required this.onRestoreAll,
  });
  final int count;
  final bool busy;
  final VoidCallback onRestoreAll;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
    decoration: BoxDecoration(
      color: TimoColors.brandMid.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.cloud_download_outlined,
          size: 18,
          color: TimoColors.brandMid,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            CollectionText.pendingBanner(count),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: TimoColors.ink,
            ),
          ),
        ),
        if (busy)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          TextButton(
            onPressed: onRestoreAll,
            child: const Text(CollectionText.restoreAllLabel),
          ),
      ],
    ),
  );
}

/// 입장을 마친 티켓이 하나도 없을 때의 "모두 보기". 만들기 버튼은 없다 —
/// 만들 공연이 없으니 눌러 봐야 같은 말을 한 번 더 듣는다.
class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CollectionLayout.pagePadding * 2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Reveal(child: TimoMascot.sad(size: 150)),
          SizedBox(height: 28),
          Reveal(
            index: 1,
            child: Text(
              CollectionText.catalogEmptyTitle,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: TimoColors.ink,
              ),
            ),
          ),
          SizedBox(height: 8),
          Reveal(
            index: 2,
            child: Text(
              CollectionText.catalogEmptyBody,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: TimoColors.inkSecondary),
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
