import 'package:flutter/material.dart';

import '../constants.dart';

/// 라벨(좌)과 값(우)을 한 줄에 배치하는 행.
///
/// 결제 화면의 금액 행과 완료 화면의 예약 정보 행이 같은 모양·같은 이유로 바뀌므로
/// 도메인 안에서 공용으로 쓴다.
class OrderInfoRow extends StatelessWidget {
  const OrderInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor = PaymentColors.value,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: PaymentColors.label),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
