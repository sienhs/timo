import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 인증 화면(회원가입 단계·로그인)의 공통 틀.
///
/// 뒤로가기 → [header] → [child](입력칸들) → 하단 고정 버튼. 헤더 자리는
/// 위젯으로 받는다. 회원가입은 로고와 'n/5'·제목·설명을, 로그인은 로고
/// 하나만 넣는다. 단계 번호·제목을 선택 값으로 늘리는 대신 자리를 내주면
/// 헤더 모양이 또 달라져도 이 틀은 건드리지 않는다(Scaffold 가 appBar·body
/// 를 위젯으로 받는 것과 같은 방식).
///
/// 키보드가 올라오면 Scaffold 가 본문을 줄이고, 본문이 `Column[Expanded(
/// 스크롤), 버튼]` 이라 버튼은 키보드 바로 위로 따라 올라오고 위쪽 내용만
/// 스크롤된다. 이 처리를 화면마다 반복하지 않으려고 틀을 하나로 뽑았다.
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
