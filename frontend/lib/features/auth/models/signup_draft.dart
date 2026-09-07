import 'package:flutter/foundation.dart';

/// 회원가입 단계를 지나며 채워지는 입력값 상자.
///
/// 각 화면은 자기 값을 채운 새 상자를 `copyWith` 로 만들어 다음 화면에
/// 라우트 인자로 넘긴다. 불변이라 뒤로가기로 이전 화면에 돌아가도 그 화면이
/// 들고 있던 상자는 그대로다. 마지막 화면이 이 상자 전체를 서버에 보낸다.
///
/// 필드는 서버 가입 요청 바디와 1:1 이다 (username, password, name,
/// nickname, phoneNumber).
@immutable
class SignupDraft {
  const SignupDraft({
    this.phoneNumber = '',
    this.name = '',
    this.username = '',
    this.password = '',
    this.nickname = '',
  });

  /// 숫자만 ('01012345678'). 하이픈은 화면에서만 붙인다.
  final String phoneNumber;
  final String name;
  final String username;
  final String password;
  final String nickname;

  SignupDraft copyWith({
    String? phoneNumber,
    String? name,
    String? username,
    String? password,
    String? nickname,
  }) {
    return SignupDraft(
      phoneNumber: phoneNumber ?? this.phoneNumber,
      name: name ?? this.name,
      username: username ?? this.username,
      password: password ?? this.password,
      nickname: nickname ?? this.nickname,
    );
  }

  /// 비밀번호는 로그에 찍히지 않도록 뺀다.
  @override
  String toString() =>
      'SignupDraft(phoneNumber: $phoneNumber, name: $name, '
      'username: $username, nickname: $nickname)';
}
