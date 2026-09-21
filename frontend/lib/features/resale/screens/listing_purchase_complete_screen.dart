import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../routes/app_routes.dart';
import '../constants.dart';
import '../models/purchased_trade.dart';
import '../models/trade_status.dart';
import '../widgets/resale_bottom_bar.dart';
import '../widgets/resale_summary_card.dart';
import '../widgets/trade_detail_card.dart';
import '../widgets/transfer_status_badge.dart';

/// 양도 결제 완료 화면. 결제 결과와 양도 상태를 보여 준다.
///
/// **결제가 끝났다면 양도도 끝나 있다.** 코인 전송과 소유권 이전이 체결 응답
/// 전에 동기로 끝나므로(서버 `PurchaseService`), 200 을 받았다는 것 자체가
/// 양도까지 끝났다는 뜻이고 상태는 언제나 `CONFIRMED` 다.
///
/// 그래서 이 화면은 아무것도 묻지 않는다. 예전에는 체결 응답이 `PENDING`(202)
/// 으로 와서 같은 체결 번호로 상태를 되풀이해 물었는데, 서버가 동기 처리로
/// 바뀌면서 물어볼 것이 없어졌다.
///
/// 그래도 배지와 문구는 [PurchasedTrade.status] 를 그대로 읽는다. 값을 안 보고
/// '완료' 를 박으면, 서버가 언젠가 다른 상태를 주기 시작했을 때 화면이 모르는
/// 채로 거짓말을 한다.
class ListingPurchaseCompleteScreen extends StatelessWidget {
  const ListingPurchaseCompleteScreen({super.key, required this.result});

  final PurchaseResult result;

  /// 내 티켓으로 간다. 결제 흐름의 화면들은 남겨 둘 이유가 없어 홈만 남긴다.
  void _openMyTickets(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.myTickets,
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final trade = result.trade;
    final settled = trade.status == TradeStatus.confirmed;

    return Scaffold(
      backgroundColor: resalePageBackground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  ResaleMetrics.horizontalPadding,
                  32,
                  ResaleMetrics.horizontalPadding,
                  16,
                ),
                child: Column(
                  children: [
                    TradePosterAvatar(url: result.posterImageUrl),
                    const SizedBox(height: 20),
                    const Text(
                      ResaleStrings.completeTitle,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TransferStatusBadge(status: trade.status),
                    const SizedBox(height: 14),
                    Text(
                      trade.status == TradeStatus.failed
                          ? ResaleStrings.transferFailedDescription
                          : ResaleStrings.transferDescription,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TradeDetailCard(trade: trade),
                  ],
                ),
              ),
            ),
            ResaleBottomBar(
              child: Column(
                children: [
                  // 양도가 끝나지 않은 상태로 올 일은 없지만, 그때도 티켓
                  // 화면으로는 갈 수 있다. 다만 가장 중요한 행동은 아니므로
                  // 끝난 뒤에만 꽉 찬 버튼이다.
                  ResaleActionButton(
                    label: ResaleStrings.viewTicketLabel,
                    onPressed: () => _openMyTickets(context),
                    filled: settled,
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.popUntil(context, (route) => route.isFirst),
                    child: const Text(
                      ResaleStrings.goHomeLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
