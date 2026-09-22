import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_dialog_frame.dart';
import '../constants.dart';

/// 팝업 가운데 회색 상자에 들어가는 요약. 무엇을 건드리는지(공연·좌석)와
/// 그 일로 오가는 금액 한 줄.
typedef TicketConfirmSummary = ({String title, String seat, String amount});

/// 되돌릴 수 없는 일을 하기 전에 한 번 묻는 팝업. 예매 취소와 양도 등록 취소가
/// 같은 틀을 쓴다.
///
/// 무엇을 하는지(공연·좌석)와 금액을 함께 보여준다 — "정말 취소할까요?" 만
/// 띄우면 어느 티켓인지 모른 채 누르게 된다.
///
/// 틀은 다른 팝업과 같되 테두리는 없다(사용자 결정). 되돌릴 수 없는 행동임은
/// 확인 버튼의 강조색(코랄)으로만 알리고, [keepLabel] 은 같은 크기의 흰 바탕·
/// 초록 테두리 버튼으로 나란히 둔다.
///
/// 하기로 했으면 true, 아니면 false.
Future<bool> showTicketConfirmDialog(
  BuildContext context, {
  required String title,
  required TicketConfirmSummary summary,
  required String body,
  required String agreeLabel,
  String keepLabel = TicketStrings.cancelConfirmKeep,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _TicketConfirmDialog(
      title: title,
      summary: summary,
      body: body,
      agreeLabel: agreeLabel,
      keepLabel: keepLabel,
    ),
  );
  return confirmed ?? false;
}

class _TicketConfirmDialog extends StatelessWidget {
  const _TicketConfirmDialog({
    required this.title,
    required this.summary,
    required this.body,
    required this.agreeLabel,
    required this.keepLabel,
  });

  final String title;
  final TicketConfirmSummary summary;
  final String body;
  final String agreeLabel;
  final String keepLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // 모서리·여백은 앱 팝업 공통([AppDialogFrame])을 따른다. 되돌릴 수 없는
    // 행동임은 확인 버튼의 강조색으로만 알린다.
    return AppDialogFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.titleSmall?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 12),
          _Summary(summary: summary),
          const SizedBox(height: 12),
          Text(
            body,
            textAlign: TextAlign.center,
            style: textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          // 안내문이 한 줄이 되면서 20 은 아래가 비어 보였다(사용자 피드백).
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: AppColors.accent,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(agreeLabel),
          ),
          const SizedBox(height: 8),
          // 확인 버튼과 같은 크기의 흰 바탕·초록 테두리 버튼(사용자 결정). 글자만
          // 있는 버튼이면 두 선택지의 무게가 달라 보인다.
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
            onPressed: () => Navigator.pop(context, false),
            child: Text(keepLabel),
          ),
        ],
      ),
    );
  }
}

/// 회색 상자. 공연명·좌석과 금액 한 줄.
class _Summary extends StatelessWidget {
  const _Summary({required this.summary});

  final TicketConfirmSummary summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        children: [
          Text(
            summary.title,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            summary.seat,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary.amount,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.primaryPressed,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
