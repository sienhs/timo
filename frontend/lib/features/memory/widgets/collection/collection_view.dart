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

  /// "모두 보기". 카탈로그가 비면 격자도 비어 아무 말이 없다 — 왜 비었는지는
  /// 알려 줘야 한다.
  Widget allBody() => widget.slots.isEmpty
      ? const _EmptyCatalog()
      : CatalogGrid(
          slots: widget.slots,
          onOpen: widget.onOpen,
          onCreateFor: widget.onCreateFor,
          onRestore: widget.onRestore ?? (_) {},
          restoring: widget.restoring,
        );

  /// "내가 만든 소장품 보기".
  Widget mineBody() => widget.tickets.isEmpty
      ? _EmptyStage(onCreate: widget.onCreate)
      : TicketOrgel(tickets: widget.tickets, onOpen: widget.onOpen);

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
              child: _FilterLayers(
                filter: filter,
                all: allBody(),
                mine: mineBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 두 보기를 겹쳐 두고 겉만 바꾼다.
///
/// 예전에는 [AnimatedSwitcher] 로 갈아 끼웠다. 그러면 필터를 누를 때마다 보고
/// 있던 쪽이 통째로 버려져서, 오르골 각도와 격자 스크롤이 처음으로 돌아가고
/// 칸마다 붙은 [Reveal] 이 initState 부터 다시 돌았다 — 칸이 열 개면 계단식
/// 등장이 1.4초. 받아 둔 목록은 그대로인데 누를 때마다 다시 불러오는 것처럼
/// 보였다.
///
/// 그래서 한 번 본 쪽은 트리에 남긴다. 가려진 동안에는 [Offstage] 로
/// 레이아웃에서 빼고 [TickerMode] 로 애니메이션을 재워, 안 보이는 곳에서 도는
/// 것이 없게 한다. 아직 한 번도 안 본 쪽은 만들지 않아서, 그쪽을 처음 여는
/// 순간의 등장 연출은 그대로다.
class _FilterLayers extends StatefulWidget {
  const _FilterLayers({
    required this.filter,
    required this.all,
    required this.mine,
  });
  final CollectionFilter filter;
  final Widget all;
  final Widget mine;

  @override
  State<_FilterLayers> createState() => _FilterLayersState();
}

class _FilterLayersState extends State<_FilterLayers>
    with SingleTickerProviderStateMixin {
  /// 0 이 "내가 만든 소장품 보기", 1 이 "모두 보기".
  late final AnimationController fade = AnimationController(
    vsync: this,
    duration: Motion.slow,
    value: widget.filter == CollectionFilter.all ? 1 : 0,
  );

  /// 들어오는 쪽과 나가는 쪽의 곡선이 달랐다(emphasized / standard). 한
  /// 컨트롤러로 양쪽을 그리므로 reverseCurve 로 같은 짝을 만든다.
  late final CurvedAnimation curve = CurvedAnimation(
    parent: fade,
    curve: Motion.emphasized,
    reverseCurve: Motion.standard,
  );

  /// 한 번이라도 보인 보기. 여기 없는 쪽은 아직 만들지 않는다.
  late final Set<CollectionFilter> visited = {widget.filter};

  @override
  void didUpdateWidget(covariant _FilterLayers oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filter == oldWidget.filter) return;
    visited.add(widget.filter);
    if (widget.filter == CollectionFilter.all) {
      fade.forward();
    } else {
      fade.reverse();
    }
  }

  @override
  void dispose() {
    curve.dispose();
    fade.dispose();
    super.dispose();
  }

  /// 보이든 숨든 감싸는 위젯의 종류와 순서는 같아야 한다. 숨을 때만 [Offstage]
  /// 를 씌우는 식으로 모양을 바꾸면 그 자리의 element 가 갈아끼워져서, 살려
  /// 두려던 [TicketOrgel] 의 State 가 그대로 버려진다. 값만 바꾼다.
  Widget layer(CollectionFilter which, Widget child, double opacity) {
    if (!visited.contains(which)) return const SizedBox.shrink();
    final showing = widget.filter == which;
    // 다 사라진 쪽은 자리도 차지하지 않고 시계도 멈춘다 — 상태(오르골 각도·격자
    // 스크롤·이미 끝난 등장)는 element 에 남아 돌아오면 이어진다.
    final hidden = opacity == 0 && !showing;
    return TickerMode(
      enabled: !hidden,
      child: Offstage(
        offstage: hidden,
        child: IgnorePointer(
          ignoring: !showing,
          child: ExcludeSemantics(
            excluding: !showing,
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: 0.97 + 0.03 * opacity,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: curve,
    builder: (context, _) {
      final t = curve.value.clamp(0.0, 1.0);
      return Stack(
        fit: StackFit.expand,
        children: [
          layer(CollectionFilter.mine, widget.mine, 1 - t),
          layer(CollectionFilter.all, widget.all, t),
        ],
      );
    },
  );
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
  const _EmptyCatalog();

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
  const _EmptyStage({required this.onCreate});
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
