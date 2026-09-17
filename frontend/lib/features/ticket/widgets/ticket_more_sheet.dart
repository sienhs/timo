import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/my_ticket.dart';

/// 티켓 카드 더보기(⋮)에서 고른 것.
enum TicketMoreAction { registerListing, cancelReservation }

/// 티켓 하나로 할 수 있는 일을 담은 바텀시트.
///
/// 시안에는 이 자리가 없다. 카드에 버튼을 하나 더 붙이면 시안의 배치가
/// 깨지고, 예매 취소는 자주 쓰는 기능도 아니라 한 겹 안으로 넣었다.
///
/// 양도 등록과 예매 취소 둘이다. 등록을 위에, 되돌릴 수 없는 취소를 아래에
/// 둔다. 요구사항대로 둘 중 유리한 쪽을 고르는 자리라 한 시트에 나란히 있다.
///
/// 할 수 없는 항목은 **지우지 않고 비활성으로** 두고 이유를 그 아래 한 줄로
/// 적는다. 없으면 왜 못 하는지 알 길이 없다. 이유는 서버가 준 티켓 정보로
/// 미리 안다(S15P21D206-331) — 이미 마켓에 올렸는지, 양도로 받은 티켓인지,
/// 공연이 코앞인지.
Future<TicketMoreAction?> showTicketMoreSheet(
  BuildContext context, {
  required MyTicket ticket,
  required DateTime now,
}) {
  return showModalBottomSheet<TicketMoreAction>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _TicketMoreSheet(ticket: ticket, now: now),
  );
}

class _TicketMoreSheet extends StatelessWidget {
  const _TicketMoreSheet({required this.ticket, required this.now});

  final MyTicket ticket;
  final DateTime now;

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
    // 이 시트는 손에 있는 티켓([MyTicket.isHeld])에만 열린다. 등록이 막히는
    // 이유는 "이미 올렸다" 하나뿐이다.
    final canList = ticket.isUsable;
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
          _ActionTile(
            icon: Icons.storefront_outlined,
            // 빠른 메뉴의 양도마켓과 같은 아이콘. 어디로 가는지 미리 알린다.
            iconColor: AppColors.primary,
            label: TicketStrings.registerListing,
            reason: canList ? null : TicketStrings.alreadyListed,
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
