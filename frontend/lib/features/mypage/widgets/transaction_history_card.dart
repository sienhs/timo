import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/wallet_transaction.dart';
import 'my_page_card.dart';
import 'transaction_tile.dart';

/// 코인 내역 카드. 최근 [visibleLimit] 건을 최신순으로 보여 준다. 거르는 장치는
/// 없다. 목록이 남은 자리를 받아 거기서 굴러야 하므로 높이가 묶인 자리에 놓고,
/// 스크롤 뷰 같은 높이 없는 자리에는 바로 넣지 못한다.
class TransactionHistoryCard extends StatelessWidget {
  const TransactionHistoryCard({
    super.key,
    required this.transactions,
    this.visibleLimit = MyPageMetrics.recentTransactionCount,
  });

  /// 최신순 거래. 앞에서 [visibleLimit] 건까지 그린다.
  final List<WalletTransaction> transactions;

  final int visibleLimit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final visible = transactions.take(visibleLimit).toList();

    return MyPageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(MyPageStrings.historyTitle, style: textTheme.headlineSmall),
          const SizedBox(height: MyPageMetrics.historyTopGap),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: MyPageMetrics.transactionVerticalPadding,
              ),
              child: Text(
                MyPageStrings.noTransactions,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            // 목록만 높이를 묶어 그 안에서 스크롤한다. 높이는 남은 자리와
            // [MyPageMetrics.historyMaxHeight] 중 작은 쪽, 내역이 적으면 그만큼만이다.
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: MyPageMetrics.historyMaxHeight,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (_, index) =>
                      TransactionTile(transaction: visible[index]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
