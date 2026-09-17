import 'package:flutter/material.dart';

import '../../ticket/models/reservation_detail.dart';
import '../constants.dart';

/// 티켓 발행이 어디까지 갔는지 알리는 배지. 발행 중 · 완료 · 실패.
///
/// 시안에는 '발행 중' 하나만 있다. 나머지 둘은 같은 자리에 같은 모양으로,
/// 색과 아이콘과 문구만 바꿔 그린다 — 결제 직후 화면에서 상태가 바뀌는 것이
/// 눈에 들어오면서도 화면 구조는 시안 그대로다.
class IssueStatusBadge extends StatelessWidget {
  const IssueStatusBadge({super.key, required this.status});

  final TicketIssueStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, icon, background, foreground) = switch (status) {
      TicketIssueStatus.issuing => (
        PaymentConstants.issuingBadgeLabel,
        Icons.autorenew,
        PaymentColors.issuingBadgeBackground,
        PaymentColors.issuingBadgeForeground,
      ),
      TicketIssueStatus.issued => (
        PaymentConstants.issuedBadgeLabel,
        Icons.check_circle_outline,
        PaymentColors.issuedBadgeBackground,
        PaymentColors.issuedBadgeForeground,
      ),
      TicketIssueStatus.failed => (
        PaymentConstants.issueFailedBadgeLabel,
        Icons.error_outline,
        PaymentColors.issueFailedBadgeBackground,
        PaymentColors.issueFailedBadgeForeground,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
