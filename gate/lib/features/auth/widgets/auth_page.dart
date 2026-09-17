import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 로그인 화면의 틀. 팬 앱 `AuthPage` 에서 가져왔다.
///
/// [header] → [child](입력칸들) → 하단 고정 버튼. 팬 앱과 달리 AppBar 가 없다 —
/// 게이트의 로그인은 앱의 첫 화면이라 돌아갈 곳이 없다.
///
/// 키보드가 올라오면 Scaffold 가 본문을 줄이고, 본문이 `Column[Expanded(
/// 스크롤), 버튼]` 이라 버튼은 키보드 바로 위로 따라 올라오고 위쪽 내용만
/// 스크롤된다.
///
/// `onPressed` 가 null 이면 버튼이 회색 비활성으로 그려진다. [isBusy] 이면
/// 초록색을 유지한 채 스피너를 보여주고 눌리지 않는다(요청 중 더블탭 방지).
class AuthPage extends StatelessWidget {
  const AuthPage({
    super.key,
    required this.header,
    required this.child,
    required this.buttonLabel,
    required this.onPressed,
    this.isBusy = false,
  });

  /// 상태 바 아래 첫 내용까지의 여백. AppBar 가 없어 그만큼 띄운다.
  static const _topPadding = 40.0;

  final Widget header;
  final Widget child;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    const side = AuthMetrics.pagePadding;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(side, _topPadding, side, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    const SizedBox(height: AuthMetrics.headerGap),
                    child,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(side, 0, side, 16),
              child: FilledButton(
                onPressed: isBusy ? null : onPressed,
                // 요청 중에는 비활성이지만 회색이 아니라 초록을 유지한다.
                // 회색이면 "왜 안 눌리지" 로 읽히고, 초록+스피너면 "처리 중"
                // 으로 읽힌다.
                style: isBusy
                    ? FilledButton.styleFrom(
                        disabledBackgroundColor: AppColors.primary,
                        disabledForegroundColor: AppColors.onPrimary,
                      )
                    : null,
                child: isBusy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
