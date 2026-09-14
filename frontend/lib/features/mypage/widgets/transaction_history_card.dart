import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/wallet_transaction.dart';
import 'my_page_card.dart';
import 'transaction_tile.dart';

/// 사용 내역 카드. 최근 몇 건을 전체·충전·사용으로 걸러 보여 준다.
///
/// 필터는 서버에 다시 묻지 않고 받아 둔 목록을 여기서 거른다. 최근 몇 건만
/// 다루는 자리라 그 정도는 화면이 해도 된다. 전체 내역 화면이 생기면 그쪽은
/// 서버 필터를 쓸 것이고, 그건 그쪽 사정이다.
///
/// 고른 필터는 이 카드만의 상태라 여기 둔다. 화면이 알 이유가 없다.
class TransactionHistoryCard extends StatefulWidget {
  const TransactionHistoryCard({
    super.key,
    required this.transactions,
    required this.onSeeAllPressed,
  });

  /// 최신순 거래. 이 중 [MyPageMetrics.recentTransactionCount] 건만 그린다.
  final List<WalletTransaction> transactions;

  final VoidCallback onSeeAllPressed;

  @override
  State<TransactionHistoryCard> createState() => _TransactionHistoryCardState();
}

class _TransactionHistoryCardState extends State<TransactionHistoryCard> {
  TransactionFilter _filter = TransactionFilter.all;

  List<WalletTransaction> get _visible => widget.transactions
      .where(_filter.accepts)
      .take(MyPageMetrics.recentTransactionCount)
      .toList();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final visible = _visible;

    return MyPageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  MyPageStrings.historyTitle,
                  style: textTheme.headlineSmall,
                ),
              ),
              _FilterSegments(
                selected: _filter,
                onSelected: (filter) => setState(() => _filter = filter),
              ),
            ],
          ),
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
            for (final (index, transaction) in visible.indexed) ...[
              if (index > 0) const Divider(),
              TransactionTile(transaction: transaction),
            ],
          const Divider(),
          const SizedBox(height: MyPageMetrics.seeAllTopGap),
          TextButton(
            onPressed: widget.onSeeAllPressed,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              textStyle: textTheme.bodySmall,
            ),
            child: const Text(MyPageStrings.seeAllHistory),
          ),
        ],
      ),
    );
  }
}

/// 전체 · 충전 · 사용 세그먼트. 고른 것은 흰 칸으로 떠 보인다.
class _FilterSegments extends StatelessWidget {
  const _FilterSegments({required this.selected, required this.onSelected});

  final TransactionFilter selected;
  final ValueChanged<TransactionFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      height: MyPageMetrics.filterHeight,
      padding: const EdgeInsets.all(MyPageMetrics.filterInset),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(MyPageMetrics.filterRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final filter in TransactionFilter.values)
            Semantics(
              button: true,
              selected: filter == selected,
              child: InkWell(
                onTap: () => onSelected(filter),
                borderRadius: BorderRadius.circular(
                  MyPageMetrics.filterRadius - MyPageMetrics.filterInset,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MyPageMetrics.filterItemHorizontalPadding,
                  ),
                  alignment: Alignment.center,
                  decoration: filter == selected
                      ? BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(
                            MyPageMetrics.filterRadius -
                                MyPageMetrics.filterInset,
                          ),
                          border: Border.all(color: AppColors.border),
                        )
                      : null,
                  child: Text(
                    filter.label,
                    style: textTheme.labelMedium?.copyWith(
                      color: filter == selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: filter == selected
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
