import 'package:flutter/services.dart';

import '../../../core/utils/formatters.dart';

/// 판매가 입력칸에 붙이는 포매터. 치는 대로 `176,000` 모양을 만든다.
///
/// 숫자 외 문자는 걷어내고 [maxDigits] 자리까지만 받는다. 커서는 항상 끝으로
/// 보낸다 — 금액은 뒤에서 자리를 늘리거나 지우는 입력이라 가운데 커서를 지켜
/// 줄 이유가 적다.
///
/// 충전 화면의 `ChargeAmountInputFormatter` 와 하는 일이 같지만 자릿수 상한이
/// 다르다. 저쪽은 정해진 한도(일곱 자리)고 이쪽은 **티켓마다 다른 정가**에서
/// 나온다. 두 화면이 같은 이유로 바뀌게 되면(금액 입력 규칙이 하나로 정해지면)
/// `core/utils` 로 올린다.
class PriceInputFormatter extends TextInputFormatter {
  const PriceInputFormatter({required this.maxDigits});

  final int maxDigits;

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

    if (digits.length > maxDigits) {
      digits = digits.substring(0, maxDigits);
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
