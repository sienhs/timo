import 'package:flutter_test/flutter_test.dart';
import 'package:timo_gate/features/auth/constants.dart';
import 'package:timo_gate/features/auth/data/mock_auth_api.dart';
import 'package:timo_gate/features/auth/models/access_token_claims.dart';

/// 토큰 본문에서 역할을 읽어 관리자인지 가르는 규칙을 고정한다.
void main() {
  test('roles 에 ADMIN 이 있으면 관리자', () {
    final token = MockAuthApi.fakeAccessToken(
      memberId: 1,
      roles: const [AuthRoles.admin],
    );

    final claims = AccessTokenClaims.parse(token);

    expect(claims.roles, [AuthRoles.admin]);
    expect(claims.isAdmin, isTrue);
  });

  test('USER·ORGANIZER 만 있으면 관리자가 아니다', () {
    final token = MockAuthApi.fakeAccessToken(
      memberId: 2,
      roles: const ['USER', 'ORGANIZER'],
    );

    expect(AccessTokenClaims.parse(token).isAdmin, isFalse);
  });

  test('패딩 없는 base64url 본문도 읽는다', () {
    // 서버가 만드는 JWT 는 `=` 패딩이 없다. 목 토큰도 그렇게 만들지만, 혹시 목이
    // 바뀌어도 이 규칙은 남아야 해서 따로 못 박는다.
    final token = MockAuthApi.fakeAccessToken(
      memberId: 1,
      roles: const [AuthRoles.admin],
    );
    expect(token, isNot(contains('=')));
    expect(AccessTokenClaims.parse(token).isAdmin, isTrue);
  });

  group('형식이 이상하면 역할 없는 값이 되어 관리자가 아니다', () {
    test('JWT 모양이 아님', () {
      expect(AccessTokenClaims.parse('not-a-jwt'), AccessTokenClaims.empty);
      expect(AccessTokenClaims.parse('a.b'), AccessTokenClaims.empty);
      expect(AccessTokenClaims.parse(''), AccessTokenClaims.empty);
    });

    test('본문이 base64 도 JSON 도 아님', () {
      expect(AccessTokenClaims.parse('h.!!!.s').isAdmin, isFalse);
      expect(AccessTokenClaims.parse('h.bm90LWpzb24.s').isAdmin, isFalse);
    });

    test('roles 클레임이 없거나 목록이 아님', () {
      // {"sub":"1"}
      expect(AccessTokenClaims.parse('h.eyJzdWIiOiIxIn0.s').isAdmin, isFalse);
      // {"roles":"ADMIN"} — 문자열 하나로 오면 우리 규약이 아니다
      expect(
        AccessTokenClaims.parse('h.eyJyb2xlcyI6IkFETUlOIn0.s').isAdmin,
        isFalse,
      );
    });
  });
}
