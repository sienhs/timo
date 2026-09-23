import '../../routes/app_routes.dart';

/// 알림을 눌렀을 때 열 화면. 푸시와 알림함이 같은 화면으로 가도록 고르는 규칙은
/// [destinationFor] 한 곳에 둔다.
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

/// 서버가 알림에 실어 보낸 종류와 번호로 열 화면을 고른다. `CONCERT` 는 공연
/// 상세(번호 없으면 null), `MARKET` 은 양도 마켓, `TRADE` 는 내 티켓이다(거래
/// 상세 화면이 없어 거래 번호는 쓰지 않는다). 모르는 종류는 null — 서버가 종류를
/// 추가해도 옛 앱이 죽지 않고 문구만 보이게 한다.
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

/// 푸시에 실려 온 값으로 열 화면을 고른다. FCM 은 `data` 값을 전부 문자열로 주고
/// 없으면 빈 문자열이라, 여기서 숫자로 걸러 [destinationFor] 에 넘긴다.
NotificationDestination? destinationForPushData(Map<String, dynamic> data) {
  final linkType = data['linkType'];
  final linkId = data['linkId'];
  return destinationFor(
    linkType is String ? linkType : null,
    linkId is String ? int.tryParse(linkId) : null,
  );
}
