import 'package:flutter/foundation.dart';

/// 로그인 성공 응답(백엔드 LoginResponseDto). 팬 앱의 같은 모델과 같다.
///
/// 이 값을 들고 다니는 곳은 [AuthSession] 하나다. 화면은 받아서 세션에 넘기기만
/// 한다. 회원의 역할(관리자인지)은 여기 없다 — [accessToken] 의 클레임에 실려
/// 있어 `AccessTokenClaims` 로 읽는다.
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
  /// 로그아웃할 때 서버에 보내 이 기기의 세션을 끊는 데도 쓴다.
  final String refreshToken;

  /// 액세스 토큰의 남은 수명. 서버는 초 단위 숫자로 준다.
  final Duration accessTokenExpiresIn;

  /// 토큰은 로그에 찍히지 않도록 뺀다.
  @override
  String toString() =>
      'AuthTokens(memberId: $memberId, '
      'accessTokenExpiresIn: $accessTokenExpiresIn)';
}
