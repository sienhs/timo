import 'package:flutter/material.dart';

import '../../motion/press_scale.dart';
import '../../motion/reveal.dart';
import '../../models/memory_ticket.dart';
import '../../theme/timo_colors.dart';
import '../../constants.dart';
import '../../models/collection_slot.dart';
import 'ticket_thumbnail.dart';

/// "모두 보기": every concert in the catalogue, two per row. Owned slots show
/// the newest ticket; empty ones are grey cards that start the creator for
/// that concert. Long-press an owned card to delete it.
class CatalogGrid extends StatelessWidget {
  const CatalogGrid({
    super.key,
    required this.slots,
    required this.onOpen,
    required this.onCreateFor,
    required this.onDelete,
  });
  final List<CollectionSlot> slots;
  final ValueChanged<MemoryTicket> onOpen, onDelete;
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
        onDelete: onDelete,
      ),
    ),
  );
}

class _SlotCell extends StatelessWidget {
  const _SlotCell({
    required this.slot,
    required this.onOpen,
    required this.onCreateFor,
    required this.onDelete,
  });
  final CollectionSlot slot;
  final ValueChanged<MemoryTicket> onOpen, onDelete;
  final ValueChanged<CollectionSlot> onCreateFor;

  @override
  Widget build(BuildContext context) {
    final ticket = slot.latest;
    if (ticket == null) {
      return Semantics(
        button: true,
        label: '${slot.title} ${CollectionText.notOwnedLabel}',
        child: PressScale(
          onTap: () => onCreateFor(slot),
          lift: 1,
          child: const TicketPlaceholder(),
        ),
      );
    }
    return Semantics(
      button: true,
      label: slot.title,
      child: GestureDetector(
        onLongPress: () => onDelete(ticket),
        child: PressScale(
          onTap: () => onOpen(ticket),
          lift: 2,
          child: Stack(
            fit: StackFit.expand,
            children: [
              TicketThumbnail(ticket: ticket),
              if (slot.tickets.length > 1)
                // Below the brand line so the two never overlap.
                Positioned(
                  top: 30,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: TimoColors.paper.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      CollectionText.ownedCount(slot.tickets.length),
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: TimoColors.brandMid,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
