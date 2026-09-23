import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/notification/push_notification_service.dart';

/// 푸시 `data` 에서 안 읽은 알림 개수를 꺼내는 규칙.
/// 서버는 `data` 값을 전부 문자열로 보낸다(`NotificationPushListener`).
void main() {
  int? read(Map<String, dynamic> data) =>
      PushNotificationService.unreadCountOf(data);

  test('문자열로 온 개수를 숫자로 읽는다', () {
    expect(read({'unreadCount': '3'}), 3);
    expect(read({'unreadCount': '0'}), 0);
  });

  test('없거나 읽을 수 없으면 null 이라 점을 건드리지 않는다', () {
    expect(read({}), isNull);
    expect(read({'unreadCount': ''}), isNull);
    expect(read({'unreadCount': 'abc'}), isNull);
    expect(read({'unreadCount': '-1'}), isNull);
  });
}
