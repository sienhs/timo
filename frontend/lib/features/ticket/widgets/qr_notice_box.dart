import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// QR 화면 아래 안내 상자. 캡처한 화면으로는 입장할 수 없다는 것을 미리 알린다.
/// 캡처 자체는 막지 않는다(`FLAG_SECURE` 없음) — 화면 공유나 접근성 도구까지 막힌다.
class QrNoticeBox extends StatelessWidget {
  const QrNoticeBox({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline,
              size: 16,
              color: AppColors.primaryPressed,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              TicketStrings.qrCaptureNotice,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
