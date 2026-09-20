import 'package:flutter_test/flutter_test.dart';

import 'package:timo/features/notification/notification_destination.dart';
import 'package:timo/routes/app_routes.dart';

/// 알림을 눌렀을 때 어디로 가는지.
///
/// 푸시를 누르든 알림함에서 누르든 같은 화면으로 가야 해서 규칙이 한 곳에 있다.
/// 화면도 Firebase 도 필요 없는 순수 규칙이라 여기서 전부 확인한다.
void main() {
  group('알림이 가리키는 화면', () {
    test('공연 알림은 그 공연 상세로 간다', () {
      expect(
        destinationFor('CONCERT', 12),
        const NotificationDestination(AppRoutes.showDetail, arguments: 12),
      );
    });

    test('공연 번호가 없으면 열지 않는다', () {
      // 어느 공연인지 알 수 없다. 엉뚱한 공연을 여는 것보다 안 여는 게 낫다.
      expect(destinationFor('CONCERT', null), isNull);
    });

    test('마켓 알림은 양도 마켓으로 간다', () {
      expect(
        destinationFor('MARKET', null),
        const NotificationDestination(AppRoutes.resaleMarket),
      );
    });

    test('판매 완료 알림은 내 티켓으로 간다', () {
      // 서버는 거래 상세로 보내라고 거래 번호를 주지만 그 화면이 앱에 없다.
      // 번호가 와도 무시하고 내 티켓을 연다.
      expect(
        destinationFor('TRADE', 77),
        const NotificationDestination(AppRoutes.myTickets),
      );
    });

    test('모르는 종류면 이동하지 않는다', () {
      // 서버가 알림 종류를 새로 추가해도 옛 앱이 죽으면 안 된다.
      expect(destinationFor('WHATEVER', 1), isNull);
      expect(destinationFor(null, null), isNull);
    });
  });

  group('푸시에 실려 온 값', () {
    test('번호가 문자열로 와도 숫자로 읽는다', () {
      // FCM 은 data 의 값을 전부 문자열로 준다.
      expect(
        destinationForPushData({'linkType': 'CONCERT', 'linkId': '12'}),
        const NotificationDestination(AppRoutes.showDetail, arguments: 12),
      );
    });

    test('번호가 빈 문자열이면 없는 것으로 본다', () {
      // 마켓처럼 가리킬 대상이 없는 알림은 빈 문자열로 온다.
      expect(
        destinationForPushData({'linkType': 'MARKET', 'linkId': ''}),
        const NotificationDestination(AppRoutes.resaleMarket),
      );
    });

    test('공연 알림인데 번호가 비어 있으면 열지 않는다', () {
      expect(
        destinationForPushData({'linkType': 'CONCERT', 'linkId': ''}),
        isNull,
      );
    });

    test('값이 아예 없어도 죽지 않는다', () {
      expect(destinationForPushData({}), isNull);
    });
  });
}
