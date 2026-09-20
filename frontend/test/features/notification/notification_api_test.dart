import 'package:flutter_test/flutter_test.dart';

import 'package:timo/features/notification/data/mock_notification_api.dart';
import 'package:timo/features/notification/models/app_notification.dart';
import 'package:timo/features/notification/models/notification_page.dart';

/// 서버 응답을 읽는 규칙과, 목이 이어 받기를 제대로 흉내 내는지.
void main() {
  group('서버 응답 읽기', () {
    test('알림 한 건을 읽는다', () {
      final notification = AppNotification.fromJson({
        'notificationId': 1042,
        'type': 'ENTRY_OPEN',
        'body': '로이킴 콘서트, 지금부터 입장할 수 있어요',
        'linkType': 'CONCERT',
        'linkId': 12,
        'read': false,
        'createdAt': '2026-09-20T20:00:00+09:00',
      });

      expect(notification.id, 1042);
      expect(notification.body, '로이킴 콘서트, 지금부터 입장할 수 있어요');
      expect(notification.linkType, 'CONCERT');
      expect(notification.linkId, 12);
      expect(notification.read, isFalse);
    });

    test('시각은 붙어 온 시간대대로 읽는다', () {
      // 기기가 어느 시간대든 가리키는 순간은 같아야 한다. 에뮬레이터가 GMT 로
      // 맞춰져 있어도 "몇 분 전" 이 아홉 시간 어긋나지 않게 하는 지점이다.
      final notification = AppNotification.fromJson(
        _json({'createdAt': '2026-09-20T20:00:00+09:00'}),
      );

      expect(notification.createdAt.toUtc(), DateTime.utc(2026, 9, 20, 11));
    });

    test('가리킬 대상이 없으면 번호가 비어 온다', () {
      final notification = AppNotification.fromJson(
        _json({'linkType': 'MARKET', 'linkId': null}),
      );

      expect(notification.linkType, 'MARKET');
      expect(notification.linkId, isNull);
    });

    test('모르는 종류가 와도 버리지 않는다', () {
      // 서버가 알림 종류를 새로 추가했을 때. 걸러 버리면 알림이 목록에서 통째로
      // 사라진다. 이동만 못 하고 문구는 보여야 한다.
      final notification = AppNotification.fromJson(
        _json({'linkType': 'SOMETHING_NEW'}),
      );

      expect(notification.linkType, 'SOMETHING_NEW');
    });

    test('목록 한 쪽을 읽는다', () {
      final page = NotificationPage.fromJson({
        'items': [
          _json({}),
          _json({'notificationId': 1041}),
        ],
        'nextCursor': 1041,
        'hasNext': true,
      });

      expect(page.items, hasLength(2));
      expect(page.nextCursor, 1041);
      expect(page.hasNext, isTrue);
    });

    test('마지막 쪽은 다음 커서가 없다', () {
      final page = NotificationPage.fromJson({
        'items': <Map<String, dynamic>>[],
        'nextCursor': null,
        'hasNext': false,
      });

      expect(page.items, isEmpty);
      expect(page.nextCursor, isNull);
      expect(page.hasNext, isFalse);
    });
  });

  group('읽음으로 바꾼 사본', () {
    test('읽음만 바뀌고 나머지는 그대로다', () {
      final before = AppNotification.fromJson(_json({}));
      final after = before.asRead();

      expect(before.read, isFalse);
      expect(after.read, isTrue);
      expect(after.id, before.id);
      expect(after.body, before.body);
      expect(after.createdAt, before.createdAt);
    });
  });

  group('목', () {
    test('쪽을 나눠 주고 커서로 이어 받는다', () async {
      final api = MockNotificationApi(latency: Duration.zero);

      final first = await api.fetchNotifications();
      expect(first.items, hasLength(MockNotificationApi.pageSize));
      expect(first.hasNext, isTrue);

      final second = await api.fetchNotifications(cursor: first.nextCursor);
      // 이어 받은 쪽에 앞 쪽의 알림이 섞이지 않는다.
      final firstIds = first.items.map((n) => n.id).toSet();
      expect(second.items.any((n) => firstIds.contains(n.id)), isFalse);
      expect(second.hasNext, isFalse);
    });

    test('읽음 처리가 안 읽은 개수에 반영된다', () async {
      final api = MockNotificationApi(latency: Duration.zero);
      final before = await api.fetchUnreadCount();
      expect(before, greaterThan(0));

      final page = await api.fetchNotifications();
      final unread = page.items.firstWhere((n) => !n.read);
      await api.markRead(unread.id);

      expect(await api.fetchUnreadCount(), before - 1);
    });

    test('모두 읽음이면 개수가 0 이 된다', () async {
      final api = MockNotificationApi(latency: Duration.zero);
      await api.markAllRead();

      expect(await api.fetchUnreadCount(), 0);
    });

    test('빈 상황은 목록도 개수도 비어 있다', () async {
      final api = MockNotificationApi(
        latency: Duration.zero,
        scenario: MockNotificationScenario.empty,
      );

      final page = await api.fetchNotifications();
      expect(page.items, isEmpty);
      expect(page.hasNext, isFalse);
      expect(await api.fetchUnreadCount(), 0);
    });
  });
}

/// 알림 한 건의 응답. [overrides] 로 보고 싶은 값만 바꾼다.
Map<String, dynamic> _json(Map<String, dynamic> overrides) => {
  'notificationId': 1042,
  'type': 'ENTRY_OPEN',
  'body': '로이킴 콘서트, 지금부터 입장할 수 있어요',
  'linkType': 'CONCERT',
  'linkId': 12,
  'read': false,
  'createdAt': '2026-09-20T20:00:00+09:00',
  ...overrides,
};
