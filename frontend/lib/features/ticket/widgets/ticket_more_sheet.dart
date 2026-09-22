import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/my_ticket.dart';

/// 티켓 카드 더보기(⋮)에서 고른 것.
enum TicketMoreAction { registerListing, cancelListing, cancelReservation }

/// 티켓 하나로 할 수 있는 일을 담은 바텀시트.
///
/// 시안에는 이 자리가 없다. 카드에 버튼을 하나 더 붙이면 시안의 배치가
/// 깨지고, 예매 취소는 자주 쓰는 기능도 아니라 한 겹 안으로 넣었다.
///
/// 양도와 예매 취소 둘이다. 양도를 위에, 되돌릴 수 없는 예매 취소를 아래에
/// 둔다. 요구사항대로 둘 중 유리한 쪽을 고르는 자리라 한 시트에 나란히 있다.
///
/// 위 자리는 **한 자리 두 상태**다. 안 올라가 있으면 `양도 등록하기`, 올라가
/// 있으면 `양도 등록 취소하기` 다. 두 항목을 나란히 두지 않는 이유는 티켓
/// 하나가 올라가 있거나 없거나 둘 중 하나라서 — 나란히 두면 어느 쪽이든 늘
/// 하나는 잠긴 채고, 잠긴 줄만 늘어난다.
///
/// 할 수 없는 항목은 **지우지 않고 비활성으로** 두고 이유를 그 아래 한 줄로
/// 적는다. 없으면 왜 못 하는지 알 길이 없다. 이유는 서버가 준 티켓 정보로
/// 미리 안다(S15P21D206-331) — 양도로 받은 티켓인지, 공연이 코앞인지.
///
/// [listingFound] 는 등록 취소를 열 수 있는지다. 티켓 응답에 매물 번호가 없어
/// 호출부가 좌석으로 맞춰 찾으므로, 찾았는지를 여기서 알 수 없어 받는다.
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
              reason: listingFound
                  ? null
                  : TicketStrings.cancelListingUnknown,
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
