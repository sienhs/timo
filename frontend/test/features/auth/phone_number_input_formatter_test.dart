import 'package:flutter_test/flutter_test.dart';

import 'package:timo/core/utils/formatters.dart';
import 'package:timo/features/auth/utils/phone_number_input_formatter.dart';

void main() {
  group('formatPhoneNumber', () {
    test('자릿수에 따라 있는 만큼만 끊는다', () {
      expect(formatPhoneNumber(''), '');
      expect(formatPhoneNumber('010'), '010');
      expect(formatPhoneNumber('0101'), '010-1');
      expect(formatPhoneNumber('0101234'), '010-1234');
      expect(formatPhoneNumber('01012345'), '010-1234-5');
      expect(formatPhoneNumber('01012345678'), '010-1234-5678');
    });

    test('하이픈이 섞여 들어와도 같은 결과', () {
      expect(formatPhoneNumber('010-1234-5678'), '010-1234-5678');
    });
  });

  group('PhoneNumberInputFormatter', () {
    const formatter = PhoneNumberInputFormatter();

    TextEditingValue type(String oldText, String newText) =>
        formatter.formatEditUpdate(
          TextEditingValue(text: oldText),
          TextEditingValue(text: newText),
        );

    test('치는 대로 하이픈을 넣고 커서를 끝에 둔다', () {
      final value = type('010-123', '010-1234');
      expect(value.text, '010-1234');
      expect(value.selection.baseOffset, value.text.length);
    });

    test('숫자 외 문자는 걷어내고 11자리를 넘으면 자른다', () {
      expect(type('', 'a010b1234c5678d9').text, '010-1234-5678');
    });

    test('백스페이스로 하이픈만 지우면 그 앞 숫자까지 지운다', () {
      // '010-1234' 에서 백스페이스 → 입력값 '010-1234' 그대로 오면 안 되고
      // '010-123' 이 되어야 지워지는 느낌이 난다.
      expect(type('010-1234-', '010-1234').text, '010-123');
      expect(type('010-', '010').text, '01');
    });

    test('숫자를 지운 경우는 그대로 반영한다', () {
      expect(type('010-1234', '010-123').text, '010-123');
    });
  });
}
