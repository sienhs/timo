import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import 'timo_logo.dart';

/// 회원가입 단계 화면의 공통 틀.
///
/// 뒤로가기 → 로고와 'n/5' → 제목 → 설명 → [child](입력칸들) → 하단 고정
/// 버튼. 각 단계 화면은 문구·입력칸·버튼 동작만 채우고 배치는 여기에 맡긴다.
///
/// 키보드가 올라오면 Scaffold 가 본문을 줄이고, 본문이 `Column[Expanded(
/// 스크롤), 버튼]` 이라 버튼은 키보드 바로 위로 따라 올라오고 위쪽 내용만
/// 스크롤된다. 이 처리를 화면마다 반복하지 않으려고 틀을 하나로 뽑았다.
///
/// `onPressed` 가 null 이면 버튼이 회색 비활성으로 그려진다. [isBusy] 이면
/// 초록색을 유지한 채 스피너를 보여주고 눌리지 않는다(요청 중 더블탭 방지).
class SignupStepPage extends StatelessWidget {
  const SignupStepPage({
    super.key,
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.buttonLabel,
    required this.onPressed,
    this.isBusy = false,
  });

  /// 1부터 [AuthMetrics.totalSteps] 까지.
  final int step;
  final String title;
  final String subtitle;
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
                    _StepHeader(step: step, title: title, subtitle: subtitle),
                    const SizedBox(height: 32),
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

/// 로고 + 'n/5' 한 줄, 제목, 설명.
class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.step,
    required this.title,
    required this.subtitle,
  });

  final int step;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const TimoLogo(),
            const Spacer(),
            Text(
              AuthStrings.stepCounter(step),
              style: textTheme.labelMedium,
              semanticsLabel: '${AuthMetrics.totalSteps}단계 중 $step단계',
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(title, style: textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(subtitle, style: textTheme.bodySmall),
      ],
    );
  }
}
