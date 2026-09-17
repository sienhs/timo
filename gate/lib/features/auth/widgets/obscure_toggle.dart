import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 입력칸 오른쪽의 비밀번호 보기/숨기기 눈 아이콘.
///
/// LabeledTextField 의 suffixIcon 자리에 넣는다. 가려진 상태([obscured])는
/// 화면이 들고 있고, 누르면 [onPressed] 로 알려 화면이 뒤집는다.
class ObscureToggle extends StatelessWidget {
  const ObscureToggle({
    super.key,
    required this.obscured,
    required this.onPressed,
  });

  final bool obscured;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      color: AppColors.textSecondary,
      tooltip: obscured ? AuthStrings.showPassword : AuthStrings.hidePassword,
      icon: Icon(
        obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      ),
    );
  }
}
