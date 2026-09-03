import 'package:flutter/material.dart';

import '../constants.dart';

/// 결제 화면들에서 쓰는 흰색 카드 껍데기. 모서리·여백·그림자를 한곳에서 관리한다.
class PaymentCard extends StatelessWidget {
  const PaymentCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaymentColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: PaymentColors.cardShadow,
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
