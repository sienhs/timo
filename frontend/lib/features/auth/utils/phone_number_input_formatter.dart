import 'package:flutter/services.dart';

import '../../../core/utils/formatters.dart';
import '../constants.dart';
import 'signup_validators.dart';

/// 전화번호 입력칸에 붙이는 포매터. 치는 대로 `010-1234-5678` 모양을 만든다.
///
/// 숫자 외 문자는 걷어내고 11자리까지만 받는다. 커서는 항상 끝으로 보낸다.
/// 가운데를 고칠 때 커서가 끝으로 튀는 단점이 있지만, 전화번호는 보통 처음부터
/// 다시 치므로 하이픈 위치를 따라가며 커서를 옮기는 계산은 하지 않았다.
///
/// 저장할 때는 하이픈을 뺀 숫자만 쓴다([SignupValidators.digitsOnly]).
class PhoneNumberInputFormatter extends TextInputFormatter {
  const PhoneNumberInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldDigits = SignupValidators.digitsOnly(oldValue.text);
    var digits = SignupValidators.digitsOnly(newValue.text);

    // 백스페이스로 하이픈만 지운 경우: 숫자는 그대로라 다시 포맷하면 하이픈이
    // 되살아나 아무것도 안 지워진 것처럼 보인다. 그래서 숫자 하나를 더 지운다.
    final deletedOnlyHyphen =
        newValue.text.length < oldValue.text.length && digits == oldDigits;
    if (deletedOnlyHyphen && digits.isNotEmpty) {
      digits = digits.substring(0, digits.length - 1);
    }

    if (digits.length > AuthMetrics.phoneDigits) {
      digits = digits.substring(0, AuthMetrics.phoneDigits);
    }

    final formatted = formatPhoneNumber(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
