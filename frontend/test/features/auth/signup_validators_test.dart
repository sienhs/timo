import 'package:flutter_test/flutter_test.dart';

import 'package:timo/features/auth/utils/signup_validators.dart';

void main() {
  group('전화번호', () {
    test('010 으로 시작하는 11자리만 통과한다', () {
      expect(SignupValidators.isValidPhone('01012345678'), isTrue);
      expect(SignupValidators.isValidPhone('0101234567'), isFalse); // 10자리
      expect(SignupValidators.isValidPhone('01112345678'), isFalse); // 011
      expect(SignupValidators.isValidPhone('010-1234-5678'), isFalse); // 하이픈
      expect(SignupValidators.isValidPhone(''), isFalse);
    });

    test('digitsOnly 는 숫자 외 문자를 걷어낸다', () {
      expect(SignupValidators.digitsOnly('010-1234-5678'), '01012345678');
      expect(SignupValidators.digitsOnly('a1 b2'), '12');
    });
  });

  test('인증번호는 숫자 6자리', () {
    expect(SignupValidators.isValidCode('123456'), isTrue);
    expect(SignupValidators.isValidCode('000000'), isTrue); // 형식은 맞다
    expect(SignupValidators.isValidCode('12345'), isFalse);
    expect(SignupValidators.isValidCode('1234567'), isFalse);
    expect(SignupValidators.isValidCode('12345a'), isFalse);
  });

  group('이름', () {
    test('한글 또는 영문 2자 이상', () {
      expect(SignupValidators.isValidName('홍길동'), isTrue);
      expect(SignupValidators.isValidName('김철'), isTrue);
      expect(SignupValidators.isValidName('John Doe'), isTrue);
      expect(SignupValidators.isValidName('김'), isFalse);
      expect(SignupValidators.isValidName(''), isFalse);
    });

    test('숫자·특수문자·조합 중인 자모는 거절한다', () {
      expect(SignupValidators.isValidName('홍길동1'), isFalse);
      expect(SignupValidators.isValidName('홍길동!'), isFalse);
      expect(SignupValidators.isValidName('ㄱㄴ'), isFalse);
    });

    test('앞뒤 공백은 무시하고, 가운데 공백은 한 칸만', () {
      expect(SignupValidators.isValidName('  홍길동 '), isTrue);
      expect(SignupValidators.isValidName('홍  길동'), isFalse);
    });
  });

  group('아이디', () {
    test('영문 소문자로 시작하는 영문·숫자·밑줄 4~20자', () {
      expect(SignupValidators.isValidUsername('timo'), isTrue);
      expect(SignupValidators.isValidUsername('user_01'), isTrue);
      expect(SignupValidators.isValidUsername('a' * 20), isTrue);
      expect(SignupValidators.isValidUsername('abc'), isFalse);
      expect(SignupValidators.isValidUsername('a' * 21), isFalse);
    });

    test('대문자·숫자 시작·한글·공백은 거절한다', () {
      expect(SignupValidators.isValidUsername('Timo'), isFalse);
      expect(SignupValidators.isValidUsername('1timo'), isFalse);
      expect(SignupValidators.isValidUsername('_timo'), isFalse);
      expect(SignupValidators.isValidUsername('티모아이디'), isFalse);
      expect(SignupValidators.isValidUsername('ti mo'), isFalse);
    });
  });

  group('닉네임', () {
    test('한글·영문·숫자 2~20자', () {
      expect(SignupValidators.isValidNickname('티모'), isTrue);
      expect(SignupValidators.isValidNickname('timo123'), isTrue);
      expect(SignupValidators.isValidNickname('가' * 20), isTrue);
      expect(SignupValidators.isValidNickname('가'), isFalse);
      expect(SignupValidators.isValidNickname('가' * 21), isFalse);
    });

    test('공백·특수문자는 거절한다', () {
      expect(SignupValidators.isValidNickname('티 모'), isFalse);
      expect(SignupValidators.isValidNickname('티모!'), isFalse);
    });
  });

  group('비밀번호', () {
    test('영문·숫자·특수문자를 모두 포함한 8~20자', () {
      expect(SignupValidators.isValidPassword('abcd123!'), isTrue);
      expect(SignupValidators.isValidPassword('Passw0rd#2026'), isTrue);
      expect(SignupValidators.isValidPassword('a1!${'x' * 17}'), isTrue); // 20자
    });

    test('길이가 벗어나면 거절한다', () {
      expect(SignupValidators.isValidPassword('abc12!'), isFalse); // 6자
      expect(
        SignupValidators.isValidPassword('a1!${'x' * 18}'),
        isFalse,
      ); // 21자
    });

    test('세 종류 중 하나라도 빠지면 거절한다', () {
      expect(SignupValidators.isValidPassword('abcdefgh!'), isFalse); // 숫자 없음
      expect(SignupValidators.isValidPassword('12345678!'), isFalse); // 영문 없음
      expect(SignupValidators.isValidPassword('abcd1234'), isFalse); // 특수문자 없음
    });

    test('공백·한글이 들어가면 거절한다', () {
      expect(SignupValidators.isValidPassword('abcd 123!'), isFalse);
      expect(SignupValidators.isValidPassword('비밀번호abc1!'), isFalse);
    });
  });
}
