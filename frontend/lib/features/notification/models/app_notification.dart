/// 알림함의 알림 한 건. 서버가 함께 주는 알림 종류(`type`)는 쓸 곳이 없어 담지
/// 않는다.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.body,
    required this.linkType,
    required this.linkId,
    required this.read,
    required this.createdAt,
  });

  final int id;

  /// 화면에 그대로 그리는 문구. 줄바꿈이 들어 있을 수 있다(양도 매물 알림은 네 줄까지).
  /// 첫 줄만 봐도 뜻이 통하게 서버가 만들어 주므로 목록에서는 잘라도 된다.
  final String body;

  /// 눌렀을 때 갈 화면의 종류(`CONCERT`·`MARKET`·`TRADE`). 모르는 값도 문자열
  /// 그대로 둔다 — 파싱에서 걸러 버리면 서버가 종류를 추가했을 때 알림 자체가
  /// 목록에서 사라진다.
  final String? linkType;

  /// [linkType] 이 가리키는 대상의 번호. 마켓처럼 대상이 없으면 null.
  final int? linkId;

  final bool read;

  final DateTime createdAt;

  /// 읽은 것으로 바꾼 사본. 알림을 누르면 서버 응답을 기다리지 않고 화면부터
  /// 바꿀 때 쓴다.
  AppNotification asRead() => AppNotification(
    id: id,
    body: body,
    linkType: linkType,
    linkId: linkId,
    read: true,
    createdAt: createdAt,
  );

  /// 서버 응답 한 줄. [createdAt] 은 시간대가 붙어서 오므로(`+09:00`) 기기
  /// 시간대로 옮겨 둔다. 시간대 없이 오는 다른 API 들과 다른 점이다.
  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: (json['notificationId'] as num).toInt(),
        body: json['body'] as String,
        linkType: json['linkType'] as String?,
        linkId: (json['linkId'] as num?)?.toInt(),
        read: json['read'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      );
}
