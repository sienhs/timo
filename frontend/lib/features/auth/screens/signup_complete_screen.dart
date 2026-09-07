import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../widgets/timo_logo.dart';

/// 가입 완료 화면. 로고(위 가운데) → 그림 → 문구 → '티켓 보러 가기'.
///
/// 이 화면 아래 스택에는 홈만 남아 있다(닉네임 화면이 입력 화면들을 지우고
/// 왔다). 그래서 버튼도, 뒤로가기도 홈으로 간다.
class SignupCompleteScreen extends StatelessWidget {
  const SignupCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const side = AuthMetrics.pagePadding;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(side, 24, side, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: TimoLogo(height: AuthMetrics.completeLogoHeight),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 시안의 일러스트(폰과 티켓) 파일이 아직 없어 아이콘으로
                      // 자리만 잡는다. 파일이 오면 Image.asset 으로 바꾼다.
                      const Icon(
                        Icons.confirmation_number_outlined,
                        size: AuthMetrics.completeIllustrationSize,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 32),
                      Text(
                        AuthStrings.completeTitle,
                        style: textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AuthStrings.completeSubtitle,
                        style: textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                child: const Text(AuthStrings.goToTickets),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
