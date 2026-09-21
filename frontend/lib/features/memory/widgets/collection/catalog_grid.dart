import 'package:flutter/material.dart';

import '../../motion/press_scale.dart';
import '../../motion/reveal.dart';
import '../../models/memory_ticket.dart';
import '../../constants.dart';
import '../../models/collection_slot.dart';
import 'ticket_thumbnail.dart';

/// "모두 보기": 입장을 마친 내 티켓이 두 장씩 한 줄로. 소장품을 만든 칸은 그
/// 소장품을, 아직 만들지 않은 칸은 흐린 포스터를 보여주고 누르면 그 티켓으로
/// 만들기가 열린다.
class CatalogGrid extends StatelessWidget {
  const CatalogGrid({
    super.key,
    required this.slots,
    required this.onOpen,
    required this.onCreateFor,
  });
  final List<CollectionSlot> slots;
  final ValueChanged<MemoryTicket> onOpen;
  final ValueChanged<CollectionSlot> onCreateFor;

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
      ),
    ),
  );
}

class _SlotCell extends StatelessWidget {
  const _SlotCell({
    required this.slot,
    required this.onOpen,
    required this.onCreateFor,
  });
  final CollectionSlot slot;
  final ValueChanged<MemoryTicket> onOpen;
  final ValueChanged<CollectionSlot> onCreateFor;

  @override
  Widget build(BuildContext context) {
    final ticket = slot.ticket;
    if (ticket == null) {
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
}
