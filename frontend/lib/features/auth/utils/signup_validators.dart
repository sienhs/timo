import '../constants.dart';

/// 회원가입 입력값 형식 검사.
///
/// 화면과 분리한 순수 함수라 위젯 없이 테스트할 수 있고, 규칙이 바뀌면
/// 여기 한 곳만 고친다. 서버 검증(`@Valid`)과 같은 규칙을 유지해야 한다.
///
/// 한글 필드(이름·닉네임)는 입력 도중 검사하지 않고 다 친 값을 검사한다.
/// 한글은 IME 가 자모를 조합하는 동안 완성되지 않은 글자가 잠깐 들어오는데,
/// 그 순간 필터로 잘라내면 입력이 깨진다.
class SignupValidators {
  SignupValidators._();

  static final _phone = RegExp(r'^010\d{8}$');
  static final _code = RegExp('^\\d{${AuthMetrics.codeLength}}\$');

  /// 한글 완성형 또는 영문. 단어 사이 공백 한 칸은 허용(영문 이름).
  static final _name = RegExp(r'^[가-힣a-zA-Z]+( [가-힣a-zA-Z]+)*$');

  /// 첫 글자는 영문 소문자, 이후 영문 소문자·숫자·밑줄.
  static final _username = RegExp(
    '^[a-z][a-z0-9_]{${AuthMetrics.usernameMinLength - 1},'
    '${AuthMetrics.usernameMaxLength - 1}}\$',
  );

  static final _nickname = RegExp(
    '^[가-힣a-zA-Z0-9]{${AuthMetrics.nicknameMinLength},'
    '${AuthMetrics.nicknameMaxLength}}\$',
  );

  /// 공백 없는 출력 가능한 ASCII 만, 길이 제한 포함.
  static final _passwordShape = RegExp(
    '^[!-~]{${AuthMetrics.passwordMinLength},'
    '${AuthMetrics.passwordMaxLength}}\$',
  );
  static final _letter = RegExp(r'[A-Za-z]');
  static final _digit = RegExp(r'\d');

  /// ASCII 특수문자 전부 (`!`~`/`, `:`~`@`, `[`~`` ` ``, `{`~`~`).
  static final _special = RegExp(r'[!-/:-@\[-`{-~]');

  /// 하이픈 등 숫자가 아닌 것을 모두 걷어낸다.
  static String digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

  static bool isValidPhone(String digits) => _phone.hasMatch(digits);

  static bool isValidCode(String code) => _code.hasMatch(code);

  static bool isValidName(String name) {
    final trimmed = name.trim();
    return trimmed.length >= AuthMetrics.nameMinLength &&
        trimmed.length <= AuthMetrics.nameMaxLength &&
        _name.hasMatch(trimmed);
  }

  static bool isValidUsername(String username) => _username.hasMatch(username);

  static bool isValidNickname(String nickname) =>
      _nickname.hasMatch(nickname.trim());

  static bool isValidPassword(String password) =>
      _passwordShape.hasMatch(password) &&
      _letter.hasMatch(password) &&
      _digit.hasMatch(password) &&
      _special.hasMatch(password);
}
