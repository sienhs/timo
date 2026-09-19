import 'package:flutter/material.dart';
import '../../../core/widgets/app_action_button.dart';

/// 결제 화면도 공통 주요 버튼의 크기와 상태를 따른다.
class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) =>
      AppActionButton(label: label, onPressed: onPressed);
}
