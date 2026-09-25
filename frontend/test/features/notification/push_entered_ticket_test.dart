import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/notification/push_notification_service.dart';

/// 푸시 `data` 에서 입장 처리된 티켓 번호를 꺼내는 규칙.
/// 서버는 `data` 값을 전부 문자열로 보낸다(`TicketEnteredPushListener`).
void main() {
  int? read(Map<String, dynamic> data) =>
      PushNotificationService.enteredTicketIdOf(data);

  test('입장 처리 푸시면 문자열로 온 티켓 번호를 숫자로 읽는다', () {
    expect(read({'type': 'TICKET_ENTERED', 'ticketId': '123'}), 123);
  });

  test('다른 종류의 푸시는 티켓 번호가 있어도 null 이다', () {
    expect(read({'type': 'LISTING_SOLD', 'ticketId': '123'}), isNull);
    expect(read({'ticketId': '123'}), isNull);
  });

  test('번호가 없거나 읽을 수 없으면 null 이다', () {
    expect(read({'type': 'TICKET_ENTERED'}), isNull);
    expect(read({'type': 'TICKET_ENTERED', 'ticketId': ''}), isNull);
    expect(read({'type': 'TICKET_ENTERED', 'ticketId': 'abc'}), isNull);
  });
}
