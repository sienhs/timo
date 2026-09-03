import 'package:flutter/material.dart';

import '../constants.dart';
import '../models/ticket_order.dart';
import '../widgets/booking_detail_card.dart';
import '../widgets/issuing_badge.dart';
import '../widgets/poster_avatar.dart';
import '../widgets/primary_action_button.dart';

/// 결제 완료 화면. 결제 결과와 예약 정보를 보여준다.
class PaymentCompleteScreen extends StatelessWidget {
  const PaymentCompleteScreen({super.key, required this.order});

  final TicketOrder order;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PaymentColors.page,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                child: Column(
                  children: [
                    PosterAvatar(assetPath: order.posterAsset),
                    const SizedBox(height: 20),
                    const Text(
                      PaymentConstants.completeTitle,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: PaymentColors.value,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const IssuingBadge(),
                    const SizedBox(height: 14),
                    const Text(
                      PaymentConstants.issuingDescription,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: PaymentColors.label,
                      ),
                    ),
                    const SizedBox(height: 24),
                    BookingDetailCard(order: order),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                children: [
                  PrimaryActionButton(
                    label: PaymentConstants.viewTicketLabel,
                    onPressed: () => _notifyTicketScreenPending(context),
                  ),
                  TextButton(
                    onPressed: () => Navigator.popUntil(
                      context,
                      (route) => route.isFirst,
                    ),
                    child: const Text(
                      PaymentConstants.goHomeLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: PaymentColors.value,
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

  /// 티켓 화면이 아직 없어 안내만 띄운다. 화면이 생기면 이동으로 교체한다.
  void _notifyTicketScreenPending(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(PaymentConstants.viewTicketPendingMessage)),
    );
  }
}
