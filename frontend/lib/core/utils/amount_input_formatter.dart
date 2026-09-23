import 'package:flutter/services.dart';

import 'formatters.dart';

/// 금액 입력칸에 붙이는 포매터. 숫자만 남기고 `10,000` 모양으로 찍으며
/// [maxDigits] 자리까지만 받는다. 커서는 항상 끝으로 보낸다.
class AmountInputFormatter extends TextInputFormatter {
  const AmountInputFormatter({required this.maxDigits});

  final int maxDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldDigits = _digitsOf(oldValue.text);
    var digits = _digitsOf(newValue.text);

    // 쉼표만 지운 백스페이스는 숫자가 그대로라 다시 포맷하면 되살아난다.
    // 그때는 숫자 하나를 더 지운다.
    final deletedOnlySeparator =
        newValue.text.length < oldValue.text.length && digits == oldDigits;
    if (deletedOnlySeparator && digits.isNotEmpty) {
      digits = digits.substring(0, digits.length - 1);
    }

    if (digits.length > maxDigits) {
      digits = digits.substring(0, maxDigits);
    }

    // 다 지웠으면 빈 칸. 0 을 찍으면 지울 수 없는 0 이 남는다.
    final amount = int.tryParse(digits);
    final formatted = amount == null ? '' : formatThousands(amount);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String _digitsOf(String text) =>
      text.replaceAll(RegExp(r'[^0-9]'), '');
}
