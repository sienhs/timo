import 'package:flutter/material.dart';

import '../constants.dart';
import 'auth_page.dart';
import 'timo_logo.dart';

/// 회원가입 단계 화면의 공통 틀.
///
/// [AuthPage] 에 단계 헤더(로고와 'n/5' → 제목 → 설명)를 끼운 것이다. 배치와
/// 키보드 처리, 하단 버튼의 비활성·요청 중 표시는 AuthPage 가 맡고, 각 단계
/// 화면은 문구·입력칸·버튼 동작만 채운다.
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
    return AuthPage(
      header: _StepHeader(step: step, title: title, subtitle: subtitle),
      buttonLabel: buttonLabel,
      onPressed: onPressed,
      isBusy: isBusy,
      child: child,
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
