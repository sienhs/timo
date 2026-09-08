import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

/// 굵은 라벨 + 입력칸. 회원가입 화면의 모든 입력칸이 이 모양이다.
///
/// - [trailing] 을 주면 입력칸 오른쪽에 붙는다('중복 확인' 버튼).
/// - [errorText] 가 있으면 코랄색으로, 없고 [helperText] 가 있으면 회색
///   (또는 [helperColor])으로 칸 아래 한 줄을 보여준다. 둘 다 없으면 줄이
///   생기지 않는다.
///
/// 안내 문구는 TextField 의 helperText 가 아니라 **칸 바깥 아래에 전체 폭으로**
/// 그린다. helperText 는 입력칸 폭 안에서만 그려지는데, 옆에 '중복 확인'
/// 버튼이 붙으면 칸이 좁아져 규칙 안내가 두 줄로 갈렸다. 대신 오류일 때는
/// 테두리 색만 직접 코랄로 바꾼다.
///
/// 테두리·모서리·힌트 색은 여기서 정하지 않고 AppTheme 의
/// inputDecorationTheme 이 정한다. 그래서 다른 화면의 TextField 도 같은
/// 모양이 나온다.
class LabeledTextField extends StatelessWidget {
  const LabeledTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.onChanged,
    this.onSubmitted,
    this.helperText,
    this.helperColor,
    this.errorText,
    this.keyboardType,
    this.inputFormatters,
    this.obscureText = false,
    this.autofocus = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.textInputAction,
    this.focusNode,
    this.autofillHints,
    this.suffixIcon,
    this.trailing,
  });

  /// 안내 문구의 왼쪽 들여쓰기. 테마 contentPadding 의 가로 값과 같아서
  /// 칸 안의 글자와 시작 위치가 맞는다.
  static const _messageIndent = 14.0;

  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? helperText;
  final Color? helperColor;
  final String? errorText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final bool autofocus;
  final bool autocorrect;
  final bool enableSuggestions;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;

  /// 이 칸이 무엇인지(아이디·비밀번호 등) OS 에 알리는 자동완성 힌트.
  /// 넘기면 저장된 로그인 정보를 제안해 준다. 안 넘기면 제안하지 않는다.
  final Iterable<String>? autofillHints;

  /// 입력칸 안쪽 오른쪽 아이콘(비밀번호 보기 토글 등).
  final Widget? suffixIcon;

  /// 입력칸 바깥 오른쪽에 붙는 위젯('중복 확인' 버튼 등).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final decorationTheme = theme.inputDecorationTheme;
    final hasError = errorText != null;

    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
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
    );

    final message = errorText ?? helperText;
    final messageStyle = hasError
        ? decorationTheme.errorStyle
        : decorationTheme.helperStyle?.copyWith(color: helperColor);

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
        if (trailing == null)
          field
        else
          Row(
            children: [
              Expanded(child: field),
              const SizedBox(width: 8),
              trailing!,
            ],
          ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: _messageIndent),
            child: Text(message, style: messageStyle),
          ),
      ],
    );
  }
}
