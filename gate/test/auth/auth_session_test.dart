import 'package:flutter_test/flutter_test.dart';
import 'package:timo_gate/features/auth/data/token_storage.dart';
import 'package:timo_gate/features/auth/models/auth_tokens.dart';
import 'package:timo_gate/features/auth/models/reissued_access_token.dart';
import 'package:timo_gate/features/auth/state/auth_session.dart';

/// 로그인 상태 상자. 저장소는 메모리 구현을 쓰고 시계는 고정한다.
/// 팬 앱의 같은 테스트와 같다.
void main() {
  final now = DateTime(2026, 9, 10, 12, 0, 0);
  const tokens = AuthTokens(
    memberId: 7,
    accessToken: 'access-jwt',
    refreshToken: 'refresh-random',
    accessTokenExpiresIn: Duration(minutes: 30),
  );

  /// 로그인 뒤 저장돼 있어야 하는 네 값.
  final savedValues = {
    TokenStorageKeys.memberId: '7',
    TokenStorageKeys.accessToken: 'access-jwt',
    TokenStorageKeys.refreshToken: 'refresh-random',
    TokenStorageKeys.accessTokenExpiresAt: now
        .add(const Duration(minutes: 30))
        .toIso8601String(),
  };

  AuthSession build(InMemoryTokenStorage storage, {DateTime? at}) =>
      AuthSession(storage: storage, now: () => at ?? now);

  group('되살리기', () {
    test('저장된 게 없으면 로그아웃 상태다', () async {
      final session = build(InMemoryTokenStorage());

      await session.restore();

      expect(session.isLoggedIn, isFalse);
      expect(session.memberId, isNull);
      expect(session.isAccessTokenExpired, isTrue);
    });

    test('네 값이 다 있으면 로그인 상태로 되살린다', () async {
      var notified = 0;
      final session = build(InMemoryTokenStorage(savedValues))
        ..addListener(() => notified++);

      await session.restore();

      expect(session.isLoggedIn, isTrue);
      expect(session.memberId, 7);
      expect(session.accessToken, 'access-jwt');
      expect(session.refreshToken, 'refresh-random');
      expect(notified, 1);
    });

    test('하나라도 빠지거나 깨져 있으면 로그아웃 상태로 두고 나머지도 지운다', () async {
      final broken = Map.of(savedValues)
        ..[TokenStorageKeys.accessTokenExpiresAt] = 'not-a-date';
      final storage = InMemoryTokenStorage(broken);
      final session = build(storage);

      await session.restore();

      expect(session.isLoggedIn, isFalse);
      expect(storage.values, isEmpty);
    });
  });

  group('로그인', () {
    test('상태를 채우고 네 값을 기기에 저장하며 알린다', () async {
      var notified = 0;
      final storage = InMemoryTokenStorage();
      final session = build(storage)..addListener(() => notified++);

      await session.signIn(tokens);

      expect(session.isLoggedIn, isTrue);
      expect(session.memberId, 7);
      // 서버가 준 '남은 초' 를 절대 시각으로 바꿔 둔다.
      expect(
        session.accessTokenExpiresAt,
        now.add(const Duration(minutes: 30)),
      );
      expect(storage.values, savedValues);
      expect(notified, 1);
    });

    test('만료 여부는 시계로 판단한다', () async {
      final storage = InMemoryTokenStorage();
      await build(storage).signIn(tokens);

      final beforeExpiry = build(
        storage,
        at: now.add(const Duration(minutes: 29)),
      );
      await beforeExpiry.restore();
      expect(beforeExpiry.isAccessTokenExpired, isFalse);

      final afterExpiry = build(
        storage,
        at: now.add(const Duration(minutes: 30)),
      );
      await afterExpiry.restore();
      expect(afterExpiry.isAccessTokenExpired, isTrue);
    });
  });

  group('로그아웃', () {
    test('상태를 비우고 기기에서 지우며 알린다. 기기 식별자는 남긴다', () async {
      var notified = 0;
      final storage = InMemoryTokenStorage({
        ...savedValues,
        TokenStorageKeys.deviceId: 'device-1',
      });
      final session = build(storage)..addListener(() => notified++);
      await session.restore();

      await session.signOut();

      expect(session.isLoggedIn, isFalse);
      expect(session.accessToken, isNull);
      expect(storage.values, {TokenStorageKeys.deviceId: 'device-1'});
      expect(notified, 2); // restore 한 번, signOut 한 번
    });
  });

  group('토큰 재발급', () {
    const reissued = ReissuedAccessToken(
      accessToken: 'access-jwt-2',
      expiresIn: Duration(minutes: 30),
    );

    test('액세스 토큰과 만료 시각만 바뀌고 나머지는 그대로다', () async {
      final storage = InMemoryTokenStorage(savedValues);
      final at = now.add(const Duration(minutes: 40));
      final session = build(storage, at: at);
      await session.restore();

      await session.renewAccessToken(reissued);

      expect(session.accessToken, 'access-jwt-2');
      expect(session.accessTokenExpiresAt, at.add(const Duration(minutes: 30)));
      expect(session.refreshToken, 'refresh-random');
      expect(session.memberId, 7);
      expect(storage.values[TokenStorageKeys.accessToken], 'access-jwt-2');
    });

    test('로그아웃 상태면 무시한다. 다녀오는 사이 로그아웃했을 수 있다', () async {
      final storage = InMemoryTokenStorage(savedValues);
      final session = build(storage);
      await session.restore();
      await session.signOut();

      await session.renewAccessToken(reissued);

      expect(session.isLoggedIn, isFalse);
      expect(storage.values, isEmpty);
    });
  });
}
