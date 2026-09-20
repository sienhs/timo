/// 알림함의 알림 한 건.
///
/// 서버는 알림 종류(`type`)도 함께 주지만 담지 않는다. 화면은 본문만 그리고
/// 어디로 갈지는 [linkType]·[linkId] 가 정하므로 쓸 곳이 없다. 종류별 아이콘처럼
/// 쓸 일이 생기면 그때 넣는다.
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

  /// 화면에 그대로 그리는 문구. **줄바꿈이 들어 있을 수 있다.**
  ///
  /// 양도 매물 알림은 요약 한 줄 아래에 공연 목록이 붙어 네 줄까지 온다. 첫 줄만
  /// 봐도 뜻이 통하게 서버가 만들어 주므로 목록에서는 잘라도 된다.
  final String body;

  /// 눌렀을 때 갈 화면의 종류(`CONCERT`·`MARKET`·`TRADE`).
  ///
  /// 뜻을 아는 값만 추려 담지 않고 **문자열 그대로** 둔다. 서버가 종류를 새로
  /// 추가하면 옛 앱은 그 값을 모르는데, 파싱에서 걸러 버리면 알림 자체가 목록에서
  /// 사라진다. 이동만 못 하고 문구는 보이는 편이 낫다.
  final String? linkType;

  /// [linkType] 이 가리키는 대상의 번호. 마켓처럼 대상이 없으면 null.
  final int? linkId;

  final bool read;

  final DateTime createdAt;

  /// 읽은 것으로 바꾼 사본.
  ///
  /// 알림을 누르면 서버 응답을 기다리지 않고 화면부터 바꾼다. 기다리면 그 사이에
  /// 다음 화면으로 넘어가 버려서, 돌아왔을 때까지 안 읽음으로 남아 보인다.
  AppNotification asRead() => AppNotification(
    id: id,
    body: body,
    linkType: linkType,
    linkId: linkId,
    read: true,
    createdAt: createdAt,
  );

  /// 서버 응답 한 줄.
  ///
  /// [createdAt] 은 `2026-09-20T20:00:00+09:00` 처럼 **시간대가 붙어서** 온다.
  /// 그래서 기기 시간대로 옮겨 둔다 — 기기가 어느 시간대든 "몇 분 전" 이 맞게
  /// 계산된다. 시간대 없이 오는 다른 API 들과 다른 점이다.
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
