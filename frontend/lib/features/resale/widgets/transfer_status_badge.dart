import 'package:flutter/material.dart';

import '../constants.dart';
import '../models/trade_status.dart';
import 'resale_card.dart';

/// 결제 완료 화면의 양도 진행 배지. 상태마다 글자·아이콘·색이 함께 바뀐다.
/// 실패는 시안에 없어 문구를 덧붙였다. 앱이 모르는 상태는 진행 중으로 본다 —
/// '양도 완료' 로 단정하면 화면이 거짓말을 한다([TradeStatus.unknown]).
class TransferStatusBadge extends StatelessWidget {
  const TransferStatusBadge({super.key, required this.status});

  final TradeStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      TradeStatus.confirmed => const ResaleChip(
        label: ResaleStrings.transferredBadge,
        background: ResaleColors.transferredBackground,
        foreground: ResaleColors.transferredForeground,
        icon: Icons.check_circle_outline,
      ),
      TradeStatus.failed => const ResaleChip(
        label: ResaleStrings.transferFailedBadge,
        background: ResaleColors.failedBackground,
        foreground: ResaleColors.failedForeground,
        icon: Icons.error_outline,
      ),
      TradeStatus.pending || TradeStatus.unknown => const ResaleChip(
        label: ResaleStrings.transferringBadge,
        background: ResaleColors.transferringBackground,
        foreground: ResaleColors.transferringForeground,
        icon: Icons.autorenew,
      ),
    };
  }
}
