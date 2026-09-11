import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 아이디 확정 팝업. 3/5 아이디 화면에서 '다음으로' 를 누르면 뜬다.
///
/// 가입 뒤에는 아이디를 바꿀 수 없으므로 넘어가기 전에 한 번 묻는다.
/// 사용자는 아이디를 그대로 쓰거나 수정하러 돌아가는 동작을 직접 고른다.
/// 시안의 빨간 느낌표는 빼고, 좌석 확인 팝업과 같은 얇은 브랜드색 테두리로
/// 앱 안 팝업 모양을 통일했다(사용자 결정).
///
/// '이 아이디 사용하기' 를 눌렀으면 true, '수정하기' 를 눌렀으면 false.
Future<bool> showSignupConfirmDialog(BuildContext context) async {
  final agreed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _SignupConfirmDialog(),
  );
  return agreed ?? false;
}

class _SignupConfirmDialog extends StatelessWidget {
  const _SignupConfirmDialog();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      // Material 의 shape.side 로는 테두리가 그려지지 않아(좌석 확인 팝업에서
      // 골든으로 확인) 배경을 비우고 테두리를 직접 그린다.
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          border: Border.all(color: AppColors.primary),
        ),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          // 문구는 가운데, 버튼은 전체 폭(사용자 결정).
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AuthStrings.confirmTitle,
              textAlign: TextAlign.center,
              style: textTheme.titleSmall?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 8),
            Text(
              AuthStrings.confirmBody,
              textAlign: TextAlign.center,
              style: textTheme.labelSmall,
            ),
            const SizedBox(height: 20),
            FilledButton(
              // 다이얼로그 버튼은 화면 하단 버튼보다 낮게 둔다.
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(AuthStrings.confirmAgree),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(AuthStrings.confirmEdit),
            ),
          ],
        ),
      ),
    );
  }
}
