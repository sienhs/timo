import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 인증 화면(회원가입 단계·로그인)의 공통 틀. 뒤로가기 → [header] → [child] →
/// 하단 고정 버튼. 키보드가 올라오면 버튼은 그 위로 따라오고 위쪽만 스크롤된다.
/// `onPressed` 가 null 이면 회색 비활성, [isBusy] 면 초록인 채 스피너를 돌린다.
class AuthPage extends StatelessWidget {
  const AuthPage({
    super.key,
    required this.header,
    required this.child,
    required this.buttonLabel,
    required this.onPressed,
    this.isBusy = false,
  });

  /// 헤더와 입력칸 사이 간격.
  static const _headerGap = 32.0;

  final Widget header;
  final Widget child;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    const side = AuthMetrics.pagePadding;

    return Scaffold(
      // 제목 없는 AppBar. 이전 화면이 있으면 뒤로가기 화살표가 자동으로 붙는다.
      appBar: AppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(side, 8, side, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    const SizedBox(height: _headerGap),
                    child,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(side, 0, side, 16),
              child: FilledButton(
                onPressed: isBusy ? null : onPressed,
                // 요청 중에는 비활성이지만 초록을 유지한다. 회색이면 "왜 안
                // 눌리지" 로, 초록+스피너면 "처리 중" 으로 읽힌다.
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
