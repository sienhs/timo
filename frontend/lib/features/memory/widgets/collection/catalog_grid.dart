import 'package:flutter/material.dart';

import '../../motion/press_scale.dart';
import '../../motion/reveal.dart';
import '../../models/memory_ticket.dart';
import '../../constants.dart';
import '../../models/collection_slot.dart';
import 'ticket_thumbnail.dart';

/// "모두 보기": 입장을 마친 내 티켓이 두 장씩 한 줄로. 소장품을 만든 칸은 그
/// 소장품을, 서버에만 있는 칸은 가져오기 카드를, 아직 만들지 않은 칸은 흐린
/// 포스터를 보여준다.
class CatalogGrid extends StatelessWidget {
  const CatalogGrid({
    super.key,
    required this.slots,
    required this.onOpen,
    required this.onCreateFor,
    required this.onRestore,
    this.restoring = const {},
  });
  final List<CollectionSlot> slots;
  final ValueChanged<MemoryTicket> onOpen;
  final ValueChanged<CollectionSlot> onCreateFor;
  final ValueChanged<CollectionSlot> onRestore;

  /// 지금 가져오는 중인 소장품 번호들. 그 칸은 눌러도 다시 시작하지 않는다.
  final Set<String> restoring;

  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.fromLTRB(
      CollectionLayout.pagePadding,
      8,
      CollectionLayout.pagePadding,
      40,
    ),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: CollectionLayout.columns,
      crossAxisSpacing: CollectionLayout.gridSpacing,
      mainAxisSpacing: CollectionLayout.gridSpacing,
      childAspectRatio: CollectionLayout.cardAspect,
    ),
    itemCount: slots.length,
    itemBuilder: (_, i) => Reveal(
      index: i,
      scaleFrom: 0.94,
      child: _SlotCell(
        slot: slots[i],
        onOpen: onOpen,
        onCreateFor: onCreateFor,
        onRestore: onRestore,
        restoring: restoring.contains(slots[i].remote?.goodsId),
      ),
    ),
  );
}

class _SlotCell extends StatelessWidget {
  const _SlotCell({
    required this.slot,
    required this.onOpen,
    required this.onCreateFor,
    required this.onRestore,
    required this.restoring,
  });
  final CollectionSlot slot;
  final ValueChanged<MemoryTicket> onOpen;
  final ValueChanged<CollectionSlot> onCreateFor;
  final ValueChanged<CollectionSlot> onRestore;
  final bool restoring;

  @override
  Widget build(BuildContext context) {
    final ticket = slot.ticket;
    if (ticket != null) {
      return Semantics(
        button: true,
        label: slot.title,
        child: PressScale(
          onTap: () => onOpen(ticket),
          lift: 2,
          child: TicketThumbnail(ticket: ticket),
        ),
      );
    }
    final remote = slot.remote;
    if (remote != null) {
      return Semantics(
        button: true,
        label: '${slot.title} ${CollectionText.remoteLabel}',
        child: PressScale(
          onTap: restoring ? null : () => onRestore(slot),
          lift: 1,
          child: RemoteTicketCard(
            poster: slot.poster,
            title: slot.title,
            previewUrl: remote.previewUrl,
            restoring: restoring,
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      label: '${slot.title} ${CollectionText.notOwnedLabel}',
      child: PressScale(
        onTap: () => onCreateFor(slot),
        lift: 1,
        child: TicketPlaceholder(poster: slot.poster, title: slot.title),
      ),
    );
  }
}
