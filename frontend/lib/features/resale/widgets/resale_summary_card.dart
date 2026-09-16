import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// 구매 확인·결제 완료 화면의 흰 카드. 모서리·여백·그림자를 한곳에서 관리한다.
///
/// 목록 카드([ResaleCard])와 달리 회색 바탕 위에 떠 있는 카드라 테두리 대신
/// 옅은 그림자를 쓴다. 결제 도메인의 `PaymentCard` 와 같은 모양이다 — 같은
/// 흐름(결제)의 연속된 화면이라 생김새가 갈리면 안 된다.
class ResaleSummaryCard extends StatelessWidget {
  const ResaleSummaryCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// 라벨(좌)과 값(우)을 한 줄에 배치하는 행.
///
/// 구매 확인의 금액 줄과 완료 화면의 예약 정보 줄이 같은 모양·같은 이유로
/// 바뀌므로 도메인 안에서 공용으로 쓴다.
class ResaleInfoRow extends StatelessWidget {
  const ResaleInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor = AppColors.textPrimary,
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
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
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

/// 카드 안의 가로줄.
class ResaleCardDivider extends StatelessWidget {
  const ResaleCardDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Divider(height: 1, thickness: 1, color: AppColors.border),
    );
  }
}

/// 회색 바탕 위에 카드를 올리는 화면들의 배경색.
///
/// 결제 흐름의 화면(구매 확인·결제 완료)만 이 색을 쓴다. 목록 화면은 흰
/// 바탕에 테두리 카드다 — 시안이 그렇게 갈라 놓았다.
const resalePageBackground = Color(0xFFF4F5F6);
