import 'package:flutter/foundation.dart';

/// 토큰 재발급 성공 응답. 서버가 액세스 토큰만 새로 내주므로 [AuthTokens] 와
/// 달리 회원 번호도 리프레시 토큰도 없다. 두 필드를 비워 둔 [AuthTokens] 를
/// 돌려쓰면 "여기서는 빈 게 정상" 을 쓰는 쪽마다 기억해야 해서 타입을 따로 뒀다.
@immutable
class ReissuedAccessToken {
  const ReissuedAccessToken({
    required this.accessToken,
    required this.expiresIn,
  });

  /// 서버 응답(JSON)에서 만든다. 키 이름은 백엔드 ReissueResponseDto 와 같다.
  factory ReissuedAccessToken.fromJson(Map<String, dynamic> json) =>
      ReissuedAccessToken(
        accessToken: json['accessToken'] as String,
        expiresIn: Duration(
          seconds: (json['accessTokenExpiresIn'] as num).toInt(),
        ),
      );

  /// 새로 발급된 JWT. 요청 헤더 `Authorization: Bearer …` 에 실린다.
  final String accessToken;

  /// 새 토큰의 남은 수명. 서버는 초 단위 숫자로 준다.
  final Duration expiresIn;

  /// 토큰은 로그에 찍히지 않도록 뺀다.
  @override
  String toString() => 'ReissuedAccessToken(expiresIn: $expiresIn)';
}
