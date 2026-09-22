import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/wallet_transaction.dart';
import 'my_page_card.dart';
import 'transaction_tile.dart';

/// 코인 내역 카드. 최근 [visibleLimit] 건을 최신순으로 보여 준다.
///
/// 거르는 장치를 두지 않는다(사용자 결정). 늘어난 것과 줄어든 것은 줄마다
/// 금액 색으로 이미 갈리고, 여기 실리는 건수도 한 화면에서 훑을 만큼이다.
///
/// 높이가 묶인 자리에 놓는다 — 목록이 남은 자리를 받아 거기서 굴러야 하므로,
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
            // 목록만 높이를 묶고 그 안에서 스크롤한다. 제목은 위에 붙어 있어야
            // 무엇을 보고 있는지가 스크롤과 함께 사라지지 않는다.
            //
            // 묶는 높이는 둘 중 작은 쪽이다 — 화면에 남은 자리(Flexible)와
            // [MyPageMetrics.historyMaxHeight]. 앞에 맞춰야 아래에 올 로그아웃이
            // 화면 밖으로 밀리지 않고, 뒤가 있어야 큰 화면에서 카드 하나가
            // 본문을 다 먹지 않는다.
            //
            // shrinkWrap 을 쓰는 이유: 내역이 적으면 카드도 그만큼만 높아야
            // 한다. 고정 높이를 주면 두 줄짜리 내역 아래에 빈 칸이 남는다.
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
