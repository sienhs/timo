import 'package:flutter/material.dart';

import '../constants.dart';

/// 티켓 발행이 진행 중임을 알리는 배지.
class IssuingBadge extends StatelessWidget {
  const IssuingBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: PaymentColors.issuingBadgeBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.autorenew,
            size: 14,
            color: PaymentColors.issuingBadgeForeground,
          ),
          SizedBox(width: 6),
          Text(
            PaymentConstants.issuingBadgeLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: PaymentColors.issuingBadgeForeground,
            ),
          ),
        ],
      ),
    );
  }
}
