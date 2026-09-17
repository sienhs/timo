import 'package:flutter/foundation.dart';

/// 토큰 재발급 성공 응답(백엔드 ReissueResponseDto).
///
/// [AuthTokens] 와 달리 회원 번호도 리프레시 토큰도 없다. 서버가 **액세스 토큰만**
/// 새로 내주기 때문이다. 리프레시 토큰은 회전시키지 않아 앱이 갖고 있던 것을
/// 계속 쓴다. 하나로 합치면 "여기서는 비어 있는 게 정상" 이라는 규칙을 쓰는
/// 쪽마다 기억해야 해서 타입을 따로 뒀다.
@immutable
class ReissuedAccessToken {
  const ReissuedAccessToken({
    required this.accessToken,
    required this.expiresIn,
  });

  factory ReissuedAccessToken.fromJson(Map<String, dynamic> json) =>
      ReissuedAccessToken(
        accessToken: json['accessToken'] as String,
        expiresIn: Duration(
          seconds: (json['accessTokenExpiresIn'] as num).toInt(),
        ),
      );

  /// 새로 발급된 JWT.
  final String accessToken;

  /// 새 토큰의 남은 수명.
  final Duration expiresIn;

  /// 토큰은 로그에 찍히지 않도록 뺀다.
  @override
  String toString() => 'ReissuedAccessToken(expiresIn: $expiresIn)';
}
