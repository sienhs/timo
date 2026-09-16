import 'package:flutter/services.dart';

import '../../../core/utils/formatters.dart';
import '../models/charge_amount.dart';

/// 충전 금액 입력칸에 붙이는 포매터. 치는 대로 `10,000` 모양을 만든다.
///
/// 숫자 외 문자는 걷어내고 [ChargeAmount.maxDigits] 자리까지만 받는다. 커서는
/// 항상 끝으로 보낸다 — 금액은 뒤에서 자리를 늘리거나 지우는 입력이라 가운데
/// 커서를 지켜 줄 이유가 적다(전화번호 입력칸과 같은 이유).
///
/// 앞자리 0 은 남기지 않는다(`05` 가 아니라 `5`). [formatThousands] 가 정수를
/// 다시 찍으므로 저절로 떨어진다.
class ChargeAmountInputFormatter extends TextInputFormatter {
  const ChargeAmountInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldDigits = _digitsOf(oldValue.text);
    var digits = _digitsOf(newValue.text);

    // 백스페이스로 쉼표만 지운 경우: 숫자는 그대로라 다시 포맷하면 쉼표가
    // 되살아나 아무것도 안 지워진 것처럼 보인다. 그래서 숫자 하나를 더 지운다.
    final deletedOnlySeparator =
        newValue.text.length < oldValue.text.length && digits == oldDigits;
    if (deletedOnlySeparator && digits.isNotEmpty) {
      digits = digits.substring(0, digits.length - 1);
    }

    if (digits.length > ChargeAmount.maxDigits) {
      digits = digits.substring(0, ChargeAmount.maxDigits);
    }

    // 다 지웠으면 빈 칸으로 둔다. 여기서 0 을 찍으면 지울 수 없는 0 이 남는다.
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
