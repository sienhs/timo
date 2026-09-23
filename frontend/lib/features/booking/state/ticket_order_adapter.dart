import 'package:flutter/widgets.dart';

import '../../payment/constants.dart';
import '../../payment/models/ticket_order.dart';
import 'booking_controller.dart';
import 'booking_scope.dart';

/// 좌석 선택 상태를 결제 도메인의 [TicketOrder] 로 옮긴다. 예매 도메인과 결제
/// 도메인은 이 함수 한 곳에서만 붙는다. 예매 흐름을 거쳐 왔으면 고른 좌석으로
/// 주문을 만들고, 스코프가 없으면(단독으로 연 결제 화면, 화면 단위 테스트)
/// 발표용 더미 주문을 돌려준다.
TicketOrder ticketOrderOrSample(BuildContext context) {
  final controller = BookingScope.maybeRead(context);
  if (controller == null) return PaymentConstants.sampleOrder;
  return ticketOrderOf(controller) ?? PaymentConstants.sampleOrder;
}

/// 고른 좌석이 없으면 null 을 돌려준다.
TicketOrder? ticketOrderOf(BookingController controller) {
  final seatLabel = controller.selectedSeatLabel;
  final zone = controller.selectedZone;
  if (seatLabel == null || zone == null) return null;

  final performance = controller.performance;

  return TicketOrder(
    concertTitle: performance.title,
    performedAt: performance.startAt,
    venue: performance.venue,
    seat: seatLabel,
    bookerName: controller.bookerName,
    posterUrl: performance.posterUrl,
    // 서버가 선점 응답에 실어 준 값이라 지금 잡은 자리와 반드시 맞는다. 아직
    // 안 잡았으면(예매 흐름 밖에서 연 경우) 고른 구역의 값으로 둔다.
    ticketPrice: controller.hold?.price ?? zone.price,
  );
}
