import '../models/notification_page.dart';

/// 알림함 API(`/api/v1/notifications`).
///
/// 화면은 이 인터페이스만 안다. 앱에서는 [HttpNotificationApi] 가 실제 서버에
/// 요청하고, 테스트와 화면 확인은 [MockNotificationApi] 를 쓴다. 마이페이지의
/// `MyPageApi` 와 같은 구조다.
///
/// **누구의 알림인지는 보내지 않는다.** 서버가 토큰을 보고 정한다. 그래서 남의
/// 알림에는 손댈 수 없고, 없는 번호나 남의 번호로 읽음 처리를 하면 404 다.
///
/// 반환 규칙: 실패(네트워크·서버 오류)는 `ApiException` 으로 던진다. 빈 목록은
/// 실패가 아니라 "받은 알림이 없다" 는 정상 결과다.
///
/// 푸시 기기 등록·해제는 여기 없다. 그건 화면이 아니라 `PushNotificationService`
/// 가 앱 수명에 맞춰 혼자 부르는 일이라 섞지 않는다.
abstract class NotificationApi {
  /// 내 알림 한 쪽. 최신순.
  ///
  /// [cursor] 없이 부르면 가장 최신부터다. 이어서 받을 때는 직전 쪽의
  /// `nextCursor` 를 넘긴다.
  Future<NotificationPage> fetchNotifications({int? cursor});

  /// 안 읽은 알림 수. 마이페이지 아이콘의 점을 켤지 정한다.
  ///
  /// 앱을 켤 때와 다시 돌아왔을 때만 부르고 **되풀이해 묻지 않는다.** 그 사이의
  /// 변화는 푸시가 함께 실어 보내는 값이 맡는다.
  Future<int> fetchUnreadCount();

  /// 알림 하나를 읽음으로. 이미 읽었어도 성공이다.
  Future<void> markRead(int notificationId);

  /// 내 알림을 전부 읽음으로. 하나도 없거나 이미 다 읽었어도 성공이다.
  Future<void> markAllRead();
}
