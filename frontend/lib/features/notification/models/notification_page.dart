import 'app_notification.dart';

/// 알림 목록 한 쪽. 서버가 쪽 번호가 아니라 커서("이 번호 다음부터")로 나눠 준다.
/// 위에 계속 쌓이는 목록이라 쪽 번호로 넘기면 같은 알림을 두 번 보거나 건너뛴다.
class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.nextCursor,
    required this.hasNext,
  });

  /// 최신순.
  final List<AppNotification> items;

  /// 다음 쪽을 달랄 때 넘길 값. [hasNext] 가 거짓이면 null.
  final int? nextCursor;

  final bool hasNext;

  /// 더 받을 게 없는 빈 쪽. 목록을 처음 그릴 때의 시작값으로 쓴다.
  static const empty = NotificationPage(
    items: [],
    nextCursor: null,
    hasNext: false,
  );

  factory NotificationPage.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList();
    return NotificationPage(
      items: items,
      nextCursor: (json['nextCursor'] as num?)?.toInt(),
      hasNext: json['hasNext'] as bool? ?? false,
    );
  }
}
