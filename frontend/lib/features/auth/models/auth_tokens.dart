import 'package:flutter/foundation.dart';

/// 가입·로그인 성공 응답. 서버는 둘을 같은 모양으로 준다(백엔드
/// SignupResponseDto 와 LoginResponseDto 의 필드가 같다). 앱이 그 뒤에 할 일
/// (토큰 저장 → 로그인 상태)도 같아서 모델을 하나로 쓴다.
///
/// 이 값을 들고 다니는 곳은 [AuthSession] 하나다. 화면은 받아서 세션에 넘기기만
/// 한다.
@immutable
class AuthTokens {
  const AuthTokens({
    required this.memberId,
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresIn,
  });

  /// 서버 응답(JSON)에서 만든다. 키 이름은 백엔드 DTO 와 같다.
  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
    memberId: (json['memberId'] as num).toInt(),
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    accessTokenExpiresIn: Duration(
      seconds: (json['accessTokenExpiresIn'] as num).toInt(),
    ),
  );

  final int memberId;

  /// API 호출에 쓰는 JWT. 요청 헤더 `Authorization: Bearer …` 에 실린다.
  final String accessToken;

  /// 액세스 토큰이 만료됐을 때 재발급에 쓰는 값. JWT 가 아닌 난수다.
  /// 로그아웃할 때 서버에 보내 이 기기의 세션을 끊는 데도 쓴다. 재발급은 아직
  /// 붙이지 않았다.
  final String refreshToken;

  /// 액세스 토큰의 남은 수명. 서버는 초 단위 숫자로 준다.
  final Duration accessTokenExpiresIn;

  /// 토큰은 로그에 찍히지 않도록 뺀다.
  @override
  String toString() =>
      'AuthTokens(memberId: $memberId, '
      'accessTokenExpiresIn: $accessTokenExpiresIn)';
}
