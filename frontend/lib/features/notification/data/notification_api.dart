import '../models/notification_page.dart';

/// 알림함 API(`/api/v1/notifications`). 앱은 `HttpNotificationApi`, 테스트는
/// `MockNotificationApi` 를 쓰고 실패는 `ApiException` 으로 던진다.
/// 누구의 알림인지는 서버가 토큰으로 정한다. 없는 번호나 남의 번호로 읽음 처리를
/// 하면 404 다. 푸시 기기 등록·해제는 `PushNotificationService` 가 맡는다.
abstract class NotificationApi {
  /// 내 알림 한 쪽. 최신순. [cursor] 없이 부르면 가장 최신부터고, 이어서 받을
  /// 때는 직전 쪽의 `nextCursor` 를 넘긴다.
  Future<NotificationPage> fetchNotifications({int? cursor});

  /// 안 읽은 알림 수. 앱을 켤 때와 다시 돌아왔을 때만 묻고 되풀이하지 않는다.
  /// 그 사이의 변화는 푸시가 함께 실어 보내는 값이 맡는다.
  Future<int> fetchUnreadCount();

  /// 알림 하나를 읽음으로. 이미 읽었어도 성공이다.
  Future<void> markRead(int notificationId);

  /// 내 알림을 전부 읽음으로. 하나도 없거나 이미 다 읽었어도 성공이다.
  Future<void> markAllRead();
}
