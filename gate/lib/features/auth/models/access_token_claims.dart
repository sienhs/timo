import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../constants.dart';

/// 액세스 토큰(JWT) 본문에서 앱이 읽는 값.
///
/// 로그인 응답에는 회원의 역할이 없다. 대신 서버가 토큰의 `roles` 클레임에
/// 역할을 실어 준다(백엔드 AccessTokenProvider). JWT 는 서명이지 암호화가 아니라
/// 본문은 누구나 읽을 수 있고, 서버가 권한 검사에 쓰는 것도 같은 클레임이다.
/// 그래서 "관리자 계정인가" 는 별도 API 없이 여기서 판정한다.
///
/// **이 판정은 안내용이다.** 팬 계정으로 로그인해 검표 화면까지 갈 수 없게 막는
/// 것이지, 서명을 검증하지도 않고 할 수도 없다(비밀 키는 서버에만 있다). 검증
/// 요청이 진짜 관리자에게서 왔는지는 서버가 토큰 서명으로 가려낸다.
///
/// 파싱은 실패하지 않는다. 형식이 이상하거나 클레임이 없으면 역할 없는 값
/// ([AccessTokenClaims.empty])이 된다 — 그러면 관리자가 아닌 것으로 처리돼
/// 로그인이 막힌다. 모르는 토큰을 통과시키는 쪽보다 안전하다.
@immutable
class AccessTokenClaims {
  const AccessTokenClaims({required this.roles});

  /// 역할이 없는 값. 파싱 실패와 클레임 누락이 여기로 떨어진다.
  static const empty = AccessTokenClaims(roles: []);

  /// 백엔드가 쓰는 클레임 이름.
  static const rolesClaim = 'roles';

  /// JWT 문자열에서 만든다. 두 번째 조각(본문)을 base64url 로 풀어 JSON 으로 읽는다.
  factory AccessTokenClaims.parse(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return empty;

    final Object? payload;
    try {
      payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
    } on FormatException {
      return empty;
    }
    if (payload is! Map<String, dynamic>) return empty;

    final roles = payload[rolesClaim];
    if (roles is! List) return empty;
    return AccessTokenClaims(roles: roles.whereType<String>().toList());
  }

  /// 이 회원의 역할들. 백엔드 `Role` 열거형 이름(`USER`·`ORGANIZER`·`ADMIN`).
  final List<String> roles;

  /// 게이트 앱에 로그인할 수 있는 계정인지.
  bool get isAdmin => roles.contains(AuthRoles.admin);
}
