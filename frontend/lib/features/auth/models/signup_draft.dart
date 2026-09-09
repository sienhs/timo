import 'package:flutter/foundation.dart';

/// 회원가입 단계를 지나며 채워지는 입력값 상자.
///
/// 각 화면은 자기 값을 채운 새 상자를 `copyWith` 로 만들어 다음 화면에
/// 라우트 인자로 넘긴다. 불변이라 뒤로가기로 이전 화면에 돌아가도 그 화면이
/// 들고 있던 상자는 그대로다. 마지막 화면이 이 상자 전체를 서버에 보낸다.
///
/// 필드는 서버 가입 요청 바디와 1:1 이다 (verificationTicket, phoneNumber,
/// name, username, password, nickname).
@immutable
class SignupDraft {
  const SignupDraft({
    this.phoneNumber = '',
    this.verificationTicket = '',
    this.name = '',
    this.username = '',
    this.password = '',
    this.nickname = '',
  });

  /// 숫자만 ('01012345678'). 하이픈은 화면에서만 붙인다.
  final String phoneNumber;

  /// 인증번호가 맞았을 때 서버가 준 증표. 인증번호 화면이 채우고, 가입 요청에
  /// 같이 실어 보내야 서버가 "이 번호는 본인 확인이 끝났다" 고 인정한다.
  /// 30분 뒤 만료된다.
  final String verificationTicket;
  final String name;
  final String username;
  final String password;
  final String nickname;

  SignupDraft copyWith({
    String? phoneNumber,
    String? verificationTicket,
    String? name,
    String? username,
    String? password,
    String? nickname,
  }) {
    return SignupDraft(
      phoneNumber: phoneNumber ?? this.phoneNumber,
      verificationTicket: verificationTicket ?? this.verificationTicket,
      name: name ?? this.name,
      username: username ?? this.username,
      password: password ?? this.password,
      nickname: nickname ?? this.nickname,
    );
  }

  /// 비밀번호와 티켓은 로그에 찍히지 않도록 뺀다. 티켓은 가입 권한 그 자체라
  /// 비밀번호만큼 조심해야 한다.
  @override
  String toString() =>
      'SignupDraft(phoneNumber: $phoneNumber, name: $name, '
      'username: $username, nickname: $nickname)';
}
