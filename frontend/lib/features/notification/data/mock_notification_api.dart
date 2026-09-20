import '../models/app_notification.dart';
import '../models/notification_page.dart';
import 'notification_api.dart';

/// 서버 없이 알림함을 보기 위한 [NotificationApi].
///
/// 백엔드 없이 화면을 확인할 때와 위젯 테스트가 쓴다. 읽음 처리는 실제로 이 목
/// 안의 값을 바꾼다 — 눌러서 안 읽음 표시가 사라지는 것까지 봐야 하기 때문이다.
///
/// 시각은 만들어질 때의 현재 시각에서 거꾸로 센다. 고정 날짜로 박아 두면 하루만
/// 지나도 전부 "9월 18일" 이 되어 상대 시간 표기를 볼 수 없다.
class MockNotificationApi implements NotificationApi {
  MockNotificationApi({
    this.latency = const Duration(milliseconds: 300),
    MockNotificationScenario scenario = MockNotificationScenario.normal,
  }) : _scenario = scenario,
       _notifications = _seed(scenario);

  /// 한 쪽에 몇 건씩 나눠 줄지. 이어 받기를 눈으로 보려고 서버(20)보다 작게 둔다.
  static const pageSize = 5;

  final Duration latency;
  final MockNotificationScenario _scenario;
  final List<AppNotification> _notifications;

  @override
  Future<NotificationPage> fetchNotifications({int? cursor}) async {
    await _wait();
    if (_scenario == MockNotificationScenario.error) {
      throw Exception('알림 목록을 불러오지 못했습니다');
    }

    // 커서는 "이 번호보다 작은 것부터" 다. 번호가 클수록 최신이라 최신순 정렬과
    // 커서를 같은 값 하나로 해결한다. 서버도 같은 방식이다.
    final rest = _notifications
        .where((n) => cursor == null || n.id < cursor)
        .toList();
    final items = rest.take(pageSize).toList();
    final hasNext = rest.length > items.length;

    return NotificationPage(
      items: items,
      nextCursor: hasNext ? items.last.id : null,
      hasNext: hasNext,
    );
  }

  @override
  Future<int> fetchUnreadCount() async {
    await _wait();
    return _notifications.where((n) => !n.read).length;
  }

  @override
  Future<void> markRead(int notificationId) async {
    await _wait();
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index == -1) return;
    _notifications[index] = _notifications[index].asRead();
  }

  @override
  Future<void> markAllRead() async {
    await _wait();
    for (var i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].asRead();
    }
  }

  Future<void> _wait() =>
      latency == Duration.zero ? Future.value() : Future.delayed(latency);

  /// 최신순. 번호가 클수록 최신이다.
  ///
  /// **공연 번호는 실제 서버에 있는 값을 쓴다.** 알림함만 가짜로 띄워도 알림을
  /// 누르면 공연 상세는 진짜 서버에 물어본다. 아무 번호나 넣으면 "존재하지 않는
  /// 공연입니다" 가 떠서, 이동이 잘못된 것처럼 보인다.
  ///
  /// 아래 번호는 배포 서버(api.ticketmoa.site) 기준이다. 로컬 백엔드나 DB 를 다시
  /// 만든 뒤에는 번호가 달라질 수 있고, 그때는 공연 상세가 다시 비어 보인다 —
  /// 이동 자체가 고장 난 것이 아니다.
  static List<AppNotification> _seed(MockNotificationScenario scenario) {
    if (scenario == MockNotificationScenario.empty) return [];

    final now = DateTime.now();
    AppNotification make(
      int id,
      String body,
      String? linkType,
      int? linkId,
      bool read,
      Duration ago,
    ) => AppNotification(
      id: id,
      body: body,
      linkType: linkType,
      linkId: linkId,
      read: read,
      createdAt: now.subtract(ago),
    );

    return [
      make(
        1042,
        '로이킴 콘서트, 지금부터 입장할 수 있어요',
        'CONCERT',
        24, // 로이킴 콘서트
        false,
        const Duration(minutes: 20),
      ),
      // 줄바꿈이 들어간 본문. 목록에서 두 줄로 잘리는 모양을 보려고 넣었다.
      make(
        1041,
        '찜한 공연 3건에 양도 매물이 올라왔어요\n· 로이킴 콘서트\n· Bruno Mars 내한공연\n· 이승기 콘서트',
        'MARKET',
        null,
        false,
        const Duration(hours: 5),
      ),
      make(
        1040,
        '내일은 Bruno Mars 내한공연 보는 날이에요',
        'CONCERT',
        25, // Bruno Mars 내한공연
        true,
        const Duration(days: 1, hours: 2),
      ),
      make(
        1039,
        '이승기 콘서트 예매가 내일 시작돼요',
        'CONCERT',
        23, // 이승기 콘서트
        true,
        const Duration(days: 3),
      ),
      make(
        1038,
        '로이킴 콘서트 티켓이 판매됐어요',
        'TRADE',
        77,
        true,
        const Duration(days: 4),
      ),
      make(
        1037,
        '김필 단독 콘서트까지 일주일 남았어요',
        'CONCERT',
        22, // 김필 단독 콘서트
        true,
        const Duration(days: 8),
      ),
      // 이동할 곳이 없는 알림. 서버가 종류를 새로 추가했을 때를 흉내 낸다.
      make(
        1036,
        '공지: 서비스 점검이 예정되어 있어요',
        null,
        null,
        true,
        const Duration(days: 12),
      ),
    ];
  }
}

/// 목이 보여 줄 상황.
enum MockNotificationScenario {
  /// 안 읽은 것 둘을 포함한 일곱 건.
  normal,

  /// 받은 알림이 없는 상태.
  empty,

  /// 목록 불러오기가 실패하는 상태.
  error,
}
