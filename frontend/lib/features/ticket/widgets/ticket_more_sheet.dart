import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/my_ticket.dart';

/// 티켓 카드 더보기(⋮)에서 고른 것.
enum TicketMoreAction { registerListing, cancelListing, cancelReservation }

/// 티켓 하나로 할 수 있는 일을 담은 바텀시트. 시안에는 없다. 위 자리는 안 올라가
/// 있으면 `양도 등록하기`, 올라가 있으면 `양도 등록 취소하기` 고, 아래는 예매 취소다.
/// 할 수 없는 항목은 비활성으로 두고 이유를 적는다. [listingFound] 는 매물을 찾았는지다.
Future<TicketMoreAction?> showTicketMoreSheet(
  BuildContext context, {
  required MyTicket ticket,
  required DateTime now,
  required bool listingFound,
}) {
  return showModalBottomSheet<TicketMoreAction>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) =>
        _TicketMoreSheet(ticket: ticket, now: now, listingFound: listingFound),
  );
}

class _TicketMoreSheet extends StatelessWidget {
  const _TicketMoreSheet({
    required this.ticket,
    required this.now,
    required this.listingFound,
  });

  final MyTicket ticket;
  final DateTime now;
  final bool listingFound;

  /// 예매 취소가 막힌 이유. 여러 이유가 겹치면 사용자가 풀 수 있는 순서다 —
  /// 등록은 내리면 되고, 양도로 받은 것은 영영 안 되고, 시간은 지났다.
  String? get _cancelReason {
    if (ticket.canCancel(now)) return null;
    if (ticket.isListed) return TicketStrings.cancelWhileListed;
    if (!ticket.isBooked) return TicketStrings.cancelNotBooked;
    return TicketStrings.cancelTooLate;
  }

  @override
  Widget build(BuildContext context) {
    // 이 시트는 손에 있는 티켓([MyTicket.isHeld])에만 열린다. 그래서 위
    // 자리는 올라가 있으면 취소, 아니면 등록이다.
    final listed = ticket.isListed;
    final cancelReason = _cancelReason;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 손잡이. 이 시트가 끌어 내려 닫히는 것임을 알린다.
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (listed)
            _ActionTile(
              icon: Icons.storefront_outlined,
              // 되돌릴 수 있는 일이라 파괴적 색을 쓰지 않는다. 다시 올리면 된다.
              iconColor: AppColors.primary,
              label: TicketStrings.cancelListing,
              // 매물을 못 찾았으면 보낼 번호가 없다. 눌러서 아무 일도 안
              // 일어나게 두는 대신 왜 못 하는지 적고 양도 목록 탭으로 보낸다.
              reason: listingFound ? null : TicketStrings.cancelListingUnknown,
              onTap: () =>
                  Navigator.pop(context, TicketMoreAction.cancelListing),
            )
          else
            _ActionTile(
              icon: Icons.storefront_outlined,
              // 빠른 메뉴의 양도마켓과 같은 아이콘. 어디로 가는지 미리 알린다.
              iconColor: AppColors.primary,
              label: TicketStrings.registerListing,
              // 올라가 있지 않은데 등록도 막혔다 = 손에 있으나 쓸 수 없는
              // 상태다(입장 완료 등). 그 사정은 카드가 이미 적고 있다.
              reason: ticket.isUsable ? null : TicketStrings.alreadyListed,
              onTap: () =>
                  Navigator.pop(context, TicketMoreAction.registerListing),
            ),
          _ActionTile(
            icon: Icons.cancel_outlined,
            iconColor: AppColors.accent,
            label: TicketStrings.cancelReservation,
            reason: cancelReason,
            onTap: () =>
                Navigator.pop(context, TicketMoreAction.cancelReservation),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// 시트의 항목 한 줄. [reason] 이 있으면 비활성이고 그 이유가 아래 붙는다.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.reason,
    required this.onTap,
  });

  final IconData icon;

  /// 살아 있을 때의 아이콘 색. 잠기면 회색이다.
  final Color iconColor;
  final String label;
  final String? reason;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final enabled = reason == null;

    return ListTile(
      enabled: enabled,
      leading: Icon(icon, color: enabled ? iconColor : AppColors.textDisabled),
      title: Text(
        label,
        style: textTheme.bodyLarge?.copyWith(
          color: enabled ? AppColors.textPrimary : AppColors.textDisabled,
        ),
      ),
      subtitle: reason == null
          ? null
          : Text(
              reason!,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
      onTap: onTap,
    );
  }
}
