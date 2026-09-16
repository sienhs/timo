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
/// 양도 등록은 늘 열어 둔다. 이미 올린 티켓인지 예매 응답이 알려 주지 않아
/// 화면이 가릴 수 없고, 등록 화면이 고를 수 있는 티켓만 보여 준다.
///
/// 취소가 안 되는 티켓은 항목을 **지우지 않고 비활성으로** 둔다. 없으면 왜
/// 취소를 못 하는지 알 길이 없다. 이유는 그 아래 한 줄로 적는다.
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final canCancel = ticket.canCancel(now);

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
          ListTile(
            // 빠른 메뉴의 양도마켓과 같은 아이콘. 어디로 가는지 미리 알린다.
            leading: const Icon(
              Icons.storefront_outlined,
              color: AppColors.primary,
            ),
            title: Text(
              TicketStrings.registerListing,
              style: textTheme.bodyLarge?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            onTap: () =>
                Navigator.pop(context, TicketMoreAction.registerListing),
          ),
          ListTile(
            enabled: canCancel,
            leading: Icon(
              Icons.cancel_outlined,
              color: canCancel ? AppColors.accent : AppColors.textDisabled,
            ),
            title: Text(
              TicketStrings.cancelReservation,
              style: textTheme.bodyLarge?.copyWith(
                color: canCancel
                    ? AppColors.textPrimary
                    : AppColors.textDisabled,
              ),
            ),
            subtitle: canCancel
                ? null
                : Text(
                    TicketStrings.cancelTooLate,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
            onTap: () =>
                Navigator.pop(context, TicketMoreAction.cancelReservation),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
