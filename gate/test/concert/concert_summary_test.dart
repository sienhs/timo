import 'package:flutter_test/flutter_test.dart';
import 'package:timo_gate/features/concert/constants.dart';
import 'package:timo_gate/features/concert/models/concert_summary.dart';

void main() {
  // 2026-09-20 (일) 15:00 을 "지금" 으로 고정한다.
  final now = DateTime(2026, 9, 20, 15);

  ConcertSummary concert(int id, {DateTime? start, DateTime? end}) =>
      ConcertSummary(
        id: id,
        title: '공연 $id',
        venueName: '공연장',
        startDate: start,
        endDate: end,
      );

  group('fromJson', () {
    test('서버 응답의 날짜를 읽고, 없으면 null 로 둔다', () {
      final parsed = ConcertSummary.fromJson({
        'id': 7,
        'title': '테스트 공연',
        'venueName': '체조경기장',
        'posterImageUrl': 'poster/7.png',
        'startDate': '2026-11-04T18:00:00',
        'endDate': null,
      });

      expect(parsed.id, 7);
      expect(parsed.title, '테스트 공연');
      expect(parsed.venueName, '체조경기장');
      expect(parsed.posterImageUrl, 'poster/7.png');
      expect(parsed.startDate, DateTime(2026, 11, 4, 18));
      expect(parsed.endDate, isNull);
    });

    test('깨진 날짜는 null 이고 일시 미정으로 적힌다', () {
      final parsed = ConcertSummary.fromJson({
        'id': 1,
        'title': 't',
        'venueName': 'v',
        'startDate': 'not-a-date',
      });
      expect(parsed.startDate, isNull);
      expect(parsed.whenLabel, ConcertStrings.noDate);
    });
  });

  group('whenLabel', () {
    test('하루짜리는 일시 하나', () {
      final c = concert(1, start: DateTime(2026, 11, 4, 18));
      expect(c.whenLabel, '2026.11.04 (수) 18:00');
    });

    test('여러 날이면 시작 일시 ~ 종료 날짜', () {
      final c = concert(
        1,
        start: DateTime(2026, 11, 4, 18),
        end: DateTime(2026, 11, 6, 21),
      );
      expect(c.whenLabel, '2026.11.04 (수) 18:00 ~ 2026.11.06');
    });
  });

  group('isOn', () {
    test('시작 시각이 아직 안 됐어도 같은 날이면 오늘이다', () {
      final c = concert(1, start: DateTime(2026, 9, 20, 19));
      expect(c.isOn(now), isTrue);
    });

    test('기간 안의 날이면 오늘이다', () {
      final c = concert(
        1,
        start: DateTime(2026, 9, 18, 14),
        end: DateTime(2026, 9, 22, 22),
      );
      expect(c.isOn(now), isTrue);
    });

    test('어제 끝난 공연은 아니다', () {
      final c = concert(
        1,
        start: DateTime(2026, 9, 18, 14),
        end: DateTime(2026, 9, 19, 22),
      );
      expect(c.isOn(now), isFalse);
    });
  });

  group('sortedForGate', () {
    test('오늘 → 예정(가까운 순) → 지난(최근 순) → 일시 미정', () {
      final past = concert(1, start: DateTime(2026, 8, 1));
      final pastRecent = concert(2, start: DateTime(2026, 9, 10));
      final today = concert(3, start: DateTime(2026, 9, 20, 19));
      final soon = concert(4, start: DateTime(2026, 9, 25));
      final later = concert(5, start: DateTime(2026, 12, 25));
      final unknown = concert(6);

      final sorted = ConcertSummary.sortedForGate([
        later,
        unknown,
        past,
        soon,
        today,
        pastRecent,
      ], now: now);

      expect(sorted.map((c) => c.id).toList(), [3, 4, 5, 2, 1, 6]);
    });

    test('원본 목록은 건드리지 않는다', () {
      final a = concert(1, start: DateTime(2026, 12, 1));
      final b = concert(2, start: DateTime(2026, 9, 20, 19));
      final original = [a, b];

      ConcertSummary.sortedForGate(original, now: now);

      expect(original, [a, b]);
    });
  });
}
