import 'package:flutter_test/flutter_test.dart';

import 'package:timo/features/notification/relative_time.dart';

/// 알림함의 시각 표기.
///
/// 지난 시간으로 세는 구간("N시간 전")과 날짜로 세는 구간("어제")의 경계가
/// 헷갈리기 쉬운 자리다. 사람은 23시간 전이어도 달력으로 오늘이면 오늘로 세고,
/// 25시간 전이면 어제로 센다.
void main() {
  // 낮 시각을 기준으로 잡는다. 자정 근처면 "몇 시간 전" 을 빼는 것만으로 날짜가
  // 넘어가 버려서, 시간 구간과 날짜 구간을 따로 확인할 수 없다.
  final now = DateTime(2026, 9, 20, 14, 30);

  String at(Duration ago) => relativeTime(now.subtract(ago), now: now);

  group('지난 시간으로 세는 구간', () {
    test('1분 미만은 방금', () {
      expect(at(const Duration(seconds: 0)), '방금');
      expect(at(const Duration(seconds: 59)), '방금');
    });

    test('1시간 미만은 분', () {
      expect(at(const Duration(minutes: 1)), '1분 전');
      expect(at(const Duration(minutes: 59)), '59분 전');
    });

    test('24시간 미만은 시간', () {
      expect(at(const Duration(hours: 1)), '1시간 전');
      expect(at(const Duration(hours: 23)), '23시간 전');
    });

    test('달력으로 어제여도 24시간 안이면 시간으로 센다', () {
      // 어제 저녁 8시. 달력으로는 어제지만 18시간 전이라 "어제" 보다 이쪽이 낫다.
      expect(relativeTime(DateTime(2026, 9, 19, 20, 30), now: now), '18시간 전');
    });
  });

  group('날짜로 세는 구간', () {
    test('하루 건너뛰면 어제', () {
      expect(at(const Duration(hours: 25)), '어제');
    });

    test('2일에서 5일까지는 일', () {
      expect(at(const Duration(days: 2)), '2일 전');
      expect(at(const Duration(days: 5)), '5일 전');
    });

    test('6일부터는 날짜', () {
      expect(at(const Duration(days: 6)), '9월 14일');
      expect(at(const Duration(days: 30)), '8월 21일');
    });
  });

  test('기기 시계가 뒤처져 알림이 미래로 보여도 방금으로 둔다', () {
    // "-3분 전" 같은 문구를 내보내지 않는다.
    expect(relativeTime(now.add(const Duration(minutes: 3)), now: now), '방금');
  });
}
