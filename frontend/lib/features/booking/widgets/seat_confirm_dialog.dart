import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_dialog_frame.dart';

/// 결제로 넘어가기 직전의 좌석 확인 다이얼로그. 좌석을 탭한 순간이 아니라
/// '결제하기'를 눌렀을 때 뜬다. 좌석은 제 구역 이름을 모르므로 다 만들어진
/// 이름([seatLabel])을 받는다. 사용자가 '예'를 눌렀으면 true.
Future<bool> showSeatConfirmDialog(
  BuildContext context,
  String seatLabel,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => _SeatConfirmDialog(seatLabel: seatLabel),
  );
  return confirmed ?? false;
}

class _SeatConfirmDialog extends StatelessWidget {
  const _SeatConfirmDialog({required this.seatLabel});

  final String seatLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppDialogFrame(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: '선택한 좌석이\n'),
                TextSpan(
                  text: seatLabel,
                  style: const TextStyle(color: AppColors.accent),
                ),
                const TextSpan(text: '이 맞나요?'),
              ],
            ),
            textAlign: TextAlign.center,
            style: textTheme.titleSmall?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 10),
          Text(
            '다시 돌아오려고 하면 빈 자리가 없을 수도 있어요!',
            textAlign: TextAlign.center,
            style: textTheme.labelSmall,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  // 다이얼로그 버튼은 화면 하단 버튼보다 낮게 둔다.
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('아니요'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('예'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
