import 'package:flutter/material.dart';

import '../constants.dart';

/// 결제 화면들의 하단 주요 버튼. 높이·모서리·색을 한곳에서 관리한다.
///
/// `onPressed`가 null이면 비활성 상태로 그려진다.
class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: PaymentColors.price,
          foregroundColor: PaymentColors.card,
          disabledBackgroundColor: PaymentColors.posterPlaceholder,
          disabledForegroundColor: PaymentColors.label,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}
