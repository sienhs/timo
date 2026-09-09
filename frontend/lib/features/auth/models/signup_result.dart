import 'package:flutter/foundation.dart';

/// 가입 성공 응답. 서버는 가입과 동시에 로그인 상태가 되도록 토큰을 함께 준다.
///
/// 이번(188)에는 받아만 두고 쓰지 않는다. 토큰을 기기에 저장하고 자동 로그인으로
/// 잇는 일은 로그인 작업에서 저장 방식과 함께 정한다.
@immutable
class SignupResult {
  const SignupResult({
    required this.memberId,
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresIn,
  });

  /// 서버 응답(JSON)에서 만든다. 키 이름은 백엔드 SignupResponseDto 와 같다.
  factory SignupResult.fromJson(Map<String, dynamic> json) => SignupResult(
    memberId: (json['memberId'] as num).toInt(),
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    accessTokenExpiresIn: Duration(
      seconds: (json['accessTokenExpiresIn'] as num).toInt(),
    ),
  );

  final int memberId;

  /// API 호출에 쓰는 JWT.
  final String accessToken;

  /// 액세스 토큰이 만료됐을 때 재발급에 쓰는 값. JWT 가 아닌 난수다.
  final String refreshToken;

  /// 액세스 토큰의 남은 수명. 서버는 초 단위 숫자로 준다.
  final Duration accessTokenExpiresIn;

  /// 토큰은 로그에 찍히지 않도록 뺀다.
  @override
  String toString() =>
      'SignupResult(memberId: $memberId, '
      'accessTokenExpiresIn: $accessTokenExpiresIn)';
}
