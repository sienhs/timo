import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// 굵은 라벨 + 입력칸. 팬 앱의 같은 위젯에서 게이트에 필요한 만큼만 가져왔다.
///
/// [errorText] 가 있으면 칸 아래 한 줄로 보여주고 테두리를 오류 색으로 바꾼다.
/// 안내 문구는 TextField 의 helperText 가 아니라 **칸 바깥 아래에 전체 폭으로**
/// 그린다(팬 앱과 같은 모양을 유지하기 위해).
///
/// 테두리·모서리·힌트 색은 여기서 정하지 않고 AppTheme 의 inputDecorationTheme
/// 이 정한다.
class LabeledTextField extends StatelessWidget {
  const LabeledTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.onChanged,
    this.onSubmitted,
    this.errorText,
    this.keyboardType,
    this.obscureText = false,
    this.autofocus = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.textInputAction,
    this.focusNode,
    this.autofillHints,
    this.suffixIcon,
  });

  /// 안내 문구의 왼쪽 들여쓰기. 테마 contentPadding 의 가로 값과 같아서
  /// 칸 안의 글자와 시작 위치가 맞는다.
  static const _messageIndent = 14.0;

  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool autofocus;
  final bool autocorrect;
  final bool enableSuggestions;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;

  /// 이 칸이 무엇인지(아이디·비밀번호) OS 에 알리는 자동완성 힌트.
  final Iterable<String>? autofillHints;

  /// 입력칸 안쪽 오른쪽 아이콘(비밀번호 보기 토글).
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final decorationTheme = theme.inputDecorationTheme;
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          keyboardType: keyboardType,
          obscureText: obscureText,
          autofocus: autofocus,
          autocorrect: autocorrect,
          enableSuggestions: enableSuggestions,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          // 힌트와 같은 크기여야 글자를 치기 시작할 때 칸 높이가 안 바뀐다.
          style: textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon,
            // 오류 문구를 칸 안에 넣지 않으므로 테두리 색은 여기서 바꿔 준다.
            // null 이면 테마 값(회색·초록)이 그대로 쓰인다.
            enabledBorder: hasError ? decorationTheme.errorBorder : null,
            focusedBorder: hasError ? decorationTheme.focusedErrorBorder : null,
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: _messageIndent),
            child: Text(
              errorText!,
              style: textTheme.bodySmall?.copyWith(color: AppColors.rejected),
            ),
          ),
      ],
    );
  }
}
