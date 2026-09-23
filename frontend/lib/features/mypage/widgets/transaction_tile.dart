import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../constants.dart';
import '../models/wallet_transaction.dart';

/// 거래 내역 한 줄. 왼쪽은 무엇·언제·어디서, 오른쪽은 얼마·남은 잔액이다. 늘어난
/// 거래는 초록, 줄어든 거래는 검정이고 부호도 붙여 색을 못 보는 사람도 가른다.
class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final amountColor = transaction.isCredit
        ? AppColors.primaryPressed
        : AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: MyPageMetrics.transactionVerticalPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: MyPageMetrics.transactionLineGap),
                Text(
                  '${formatMonthDayClock(transaction.occurredAt)} · '
                  '${MyPageStrings.sourceLabel(transaction.source)}',
                  style: textTheme.labelMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: MyPageMetrics.cardPadding),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${formatSignedThousands(transaction.amount)} '
                '${MyPageStrings.currencyUnit}',
                style: textTheme.titleSmall?.copyWith(color: amountColor),
              ),
              const SizedBox(height: MyPageMetrics.transactionLineGap),
              Text(
                MyPageStrings.balanceAfter(
                  formatThousands(transaction.balanceAfter),
                ),
                style: textTheme.labelMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
