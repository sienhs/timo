import 'package:flutter/material.dart';

import '../../../routes/app_routes.dart';
import '../constants.dart';
import '../models/ticket_order.dart';
import '../widgets/hold_countdown_button.dart';
import '../widgets/order_summary_card.dart';

/// 결제 화면. 주문 요약을 확인하고 결제를 진행한다.
///
/// 주문 정보는 주입받으므로 이 화면은 값의 출처(서버·더미)를 알지 않는다.
class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key, required this.order});

  final TicketOrder order;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PaymentColors.page,
      appBar: AppBar(
        backgroundColor: PaymentColors.card,
        surfaceTintColor: PaymentColors.card,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: PaymentColors.value,
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          PaymentConstants.payScreenTitle,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: PaymentColors.value,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: OrderSummaryCard(order: order),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Text(
                    PaymentConstants.holdWarning,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: PaymentColors.warning,
                    ),
                  ),
                  const SizedBox(height: 10),
                  HoldCountdownButton(
                    onPressed: () => Navigator.pushReplacementNamed(
                      context,
                      AppRoutes.paymentComplete,
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
