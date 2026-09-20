import '../../routes/app_routes.dart';

/// 알림을 눌렀을 때 열 화면.
///
/// 푸시를 눌렀을 때와 알림함에서 눌렀을 때가 **같은 화면**으로 가야 해서, 고르는
/// 규칙을 [destinationFor] 한 곳에 두고 양쪽이 그걸 쓴다.
class NotificationDestination {
  const NotificationDestination(this.routeName, {this.arguments});

  /// 열 화면의 이름. [AppRoutes] 에 등록된 값이다.
  final String routeName;

  /// 그 화면에 넘길 값. 없는 화면도 있다.
  final Object? arguments;

  @override
  bool operator ==(Object other) =>
      other is NotificationDestination &&
      other.routeName == routeName &&
      other.arguments == arguments;

  @override
  int get hashCode => Object.hash(routeName, arguments);

  @override
  String toString() =>
      'NotificationDestination($routeName, arguments: $arguments)';
}

/// 서버가 알림에 실어 보낸 종류와 번호로 열 화면을 고른다. 모르면 null 이다.
///
/// | 종류 | 여는 화면 | 번호 |
/// |---|---|---|
/// | `CONCERT` | 공연 상세 | 공연 번호. 없으면 이동하지 않는다 |
/// | `MARKET` | 양도 마켓 | 없다 |
/// | `TRADE` | 내 티켓 | 거래 번호가 오지만 쓰지 않는다 |
///
/// **`TRADE` 가 거래 번호를 안 쓰는 이유.** 서버는 거래 상세로 보내라고 번호를
/// 주는데 그 화면이 앱에 없다. 판매자가 판 티켓은 내 티켓에서 보이므로 거기로
/// 보낸다. 거래 상세 화면이 생기면 이 한 줄만 고치면 된다.
///
/// **모르는 종류에 null 을 주는 이유.** 서버가 알림 종류를 새로 추가해도 옛 앱은
/// 그 값을 모른다. 그때 예외를 던지면 알림을 누르는 것만으로 앱이 죽는다. 이동만
/// 하지 않고 문구는 그대로 보여 주는 편이 낫다.
NotificationDestination? destinationFor(String? linkType, int? linkId) {
  switch (linkType) {
    case 'CONCERT':
      // 공연 번호 없이는 어느 공연인지 알 수 없어 열지 않는다.
      if (linkId == null) return null;
      return NotificationDestination(AppRoutes.showDetail, arguments: linkId);
    case 'MARKET':
      return const NotificationDestination(AppRoutes.resaleMarket);
    case 'TRADE':
      return const NotificationDestination(AppRoutes.myTickets);
    default:
      return null;
  }
}

/// 푸시에 실려 온 값으로 열 화면을 고른다.
///
/// FCM 은 `data` 의 값을 **전부 문자열로** 준다. 번호도 문자열이고, 없을 때는
/// 빈 문자열이라 숫자로 못 바꾼다. 그래서 여기서 한 번 걸러 [destinationFor] 에
/// 넘긴다. 알림함은 이미 숫자로 받으므로 [destinationFor] 를 바로 쓴다.
NotificationDestination? destinationForPushData(Map<String, dynamic> data) {
  final linkType = data['linkType'];
  final linkId = data['linkId'];
  return destinationFor(
    linkType is String ? linkType : null,
    linkId is String ? int.tryParse(linkId) : null,
  );
}
