import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/app_routes.dart';
import '../constants.dart';
import '../models/purchased_trade.dart';
import '../models/trade_status.dart';
import '../state/resale_api_scope.dart';
import '../widgets/resale_bottom_bar.dart';
import '../widgets/resale_summary_card.dart';
import '../widgets/trade_detail_card.dart';
import '../widgets/transfer_status_badge.dart';

/// 양도 결제 완료 화면. 결제 결과와 양도 진행 상태를 보여 준다.
///
/// 결제가 끝나도 **양도는 아직 끝나지 않았다.** 코인 전송과 소유권 이전이 DB
/// 트랜잭션 밖이라, 체결 응답은 언제나 `PENDING` 이다. 그래서 이 화면은 같은
/// 체결 번호로 상태를 되풀이해 묻고, '티켓 양도 중' 배지를 '티켓 양도 완료' 로
/// 바꾼다([ResaleMetrics.tradePollInterval]).
///
/// 끝나지 않은 채로 [ResaleMetrics.tradePollTimeout] 이 지나면 묻기를 그만둔다.
/// 그때도 화면은 '양도 중' 그대로다 — 안내 문구가 이미 "완료되면 알림으로
/// 알려드릴게요" 라고 말하고 있어, 화면을 붙들고 있을 이유가 없다.
class ListingPurchaseCompleteScreen extends StatefulWidget {
  const ListingPurchaseCompleteScreen({
    super.key,
    required this.result,
    this.clock = DateTime.now,
  });

  final PurchaseResult result;

  /// 지금 시각을 읽는 함수. 묻기를 그만둘 때를 이 값으로 잰다.
  final DateTime Function() clock;

  @override
  State<ListingPurchaseCompleteScreen> createState() =>
      _ListingPurchaseCompleteScreenState();
}

class _ListingPurchaseCompleteScreenState
    extends State<ListingPurchaseCompleteScreen> {
  late PurchasedTrade _trade = widget.result.trade;
  late final DateTime _startedAt = widget.clock();

  Timer? _timer;

  /// 앞선 물음이 아직 안 끝났다. 응답이 늦어질 때 물음이 겹치지 않게 한다.
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    if (_trade.status.isSettling) {
      _timer = Timer.periodic(ResaleMetrics.tradePollInterval, (_) => _ask());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// 온체인 전송이 끝났는지 서버에 묻는다.
  ///
  /// 실패는 삼킨다. 결제는 이미 끝났고 여기서 실패한 것은 "지금 상태를 못
  /// 읽었다" 뿐이라, 완료 화면에 오류를 띄우면 결제가 잘못된 것처럼 읽힌다.
  /// 다음 주기에 다시 묻는다.
  Future<void> _ask() async {
    if (_asking) return;
    _asking = true;
    try {
      final status = await ResaleApiScope.of(
        context,
      ).fetchTradeStatus(_trade.tradeId);
      if (!mounted) return;
      setState(() => _trade = _trade.copyWith(status: status));
    } on ApiException {
      // 다음 주기에 다시 묻는다.
    } finally {
      _asking = false;
    }

    if (!mounted) return;
    final elapsed = widget.clock().difference(_startedAt);
    if (!_trade.status.isSettling ||
        elapsed >= ResaleMetrics.tradePollTimeout) {
      _timer?.cancel();
    }
  }

  /// 내 티켓으로 간다. 결제 흐름의 화면들은 남겨 둘 이유가 없어 홈만 남긴다.
  void _openMyTickets() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.myTickets,
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settled = _trade.status == TradeStatus.confirmed;

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
                    TradePosterAvatar(url: widget.result.posterImageUrl),
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
                    TransferStatusBadge(status: _trade.status),
                    const SizedBox(height: 14),
                    Text(
                      _trade.status == TradeStatus.failed
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
                    TradeDetailCard(trade: _trade),
                  ],
                ),
              ),
            ),
            ResaleBottomBar(
              child: Column(
                children: [
                  // 양도가 끝나기 전에도 티켓 화면으로는 갈 수 있다. 거기서
                  // 진행 중인 티켓을 볼 수 있어서다. 다만 지금 이 화면에서
                  // 가장 중요한 행동은 아니므로 끝난 뒤에만 꽉 찬 버튼이다.
                  ResaleActionButton(
                    label: ResaleStrings.viewTicketLabel,
                    onPressed: _openMyTickets,
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
