import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/ticket/models/entry_pass.dart';

/// 서버가 발급한 입장 QR 한 장의 남은 시간 셈. 화면이 매초 이 값으로
/// 카운트다운과 진행 바를 그린다.
void main() {
  final received = DateTime(2026, 9, 14, 19);
  const token = 'timo:entry:1:107.1789736400.AbCdEfGhIjKlMnOpQrStUv';

  EntryPass pass({Duration lifetime = const Duration(seconds: 30)}) =>
      EntryPass(token: token, lifetime: lifetime, receivedAt: received);

  group('서버 응답 읽기', () {
    test('문자열은 그대로, 수명은 초로 읽고 받은 시각을 찍는다', () {
      final pass = EntryPass.fromJson({
        'token': token,
        'expiresInSeconds': 30,
      }, receivedAt: received);

      expect(pass.token, token);
      expect(pass.lifetime, const Duration(seconds: 30));
      expect(pass.receivedAt, received);
      expect(pass.expiresAt, DateTime(2026, 9, 14, 19, 0, 30));
    });
  });

  group('남은 시간', () {
    test('받은 직후에는 수명 전부가 남는다', () {
      expect(pass().remaining(received), const Duration(seconds: 30));
      expect(pass().progress(received), 1.0);
    });

    test('시간이 지나면 남은 시간이 준다', () {
      final later = received.add(const Duration(seconds: 20));

      expect(pass().remaining(later), const Duration(seconds: 10));
      expect(pass().progress(later), closeTo(1 / 3, 0.001));
    });

    test('수명이 다 지나면 0 이고 음수로 내려가지 않는다', () {
      final later = received.add(const Duration(minutes: 5));

      expect(pass().remaining(later), Duration.zero);
      expect(pass().progress(later), 0.0);
    });

    // 30 을 앱에 박아 두면 서버가 60초로 늘렸을 때 화면이 절반만 세고 새로 받는다.
    test('수명은 서버가 준 값을 그대로 따른다', () {
      final long = pass(lifetime: const Duration(seconds: 60));

      expect(
        long.remaining(received.add(const Duration(seconds: 45))),
        const Duration(seconds: 15),
      );
    });

    test('수명이 0 이면 비율도 0 이다', () {
      expect(pass(lifetime: Duration.zero).progress(received), 0);
    });
  });
}
