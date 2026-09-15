import 'package:flutter/widgets.dart';

import '../../payment/constants.dart';
import '../../payment/models/ticket_order.dart';
import '../data/mock_booking_data.dart';
import 'booking_controller.dart';
import 'booking_scope.dart';

/// 좌석 선택 상태를 결제 도메인의 [TicketOrder] 로 옮긴다.
///
/// 결제 화면은 [TicketOrder] 만 받아 그리므로 예매 도메인과 결제 도메인은
/// 이 함수 한 곳에서만 붙는다. 서버가 붙으면 주문 생성 API 응답이 이 자리를
/// 대신하고, 이 파일만 지우면 된다.
///
/// 라우트에서 쓰는 진입점. 예매 흐름을 거쳐 왔으면 고른 좌석으로 주문을
/// 만들고, 그렇지 않으면 발표용 더미 주문을 돌려준다.
///
/// 스코프가 아예 없는 경우까지 여기서 흡수하는 이유: 결제 화면은 예매 흐름
/// 밖에서 단독으로 열릴 수 있고(디자인 확인, 화면 단위 테스트), 그때
/// AppRoutes 가 BookingScope 를 요구하면 라우트만 띄우는 테스트가 깨진다.
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
    bookerName: MockBookingData.bookerName,
    posterUrl: performance.posterUrl,
    // 잡은 자리의 값을 쓴다. 서버가 선점 응답에 실어 준 값이라 지금 잡고 있는
    // 자리와 반드시 맞는다. 아직 안 잡았으면(결제 화면을 예매 흐름 밖에서 연
    // 경우) 고른 구역의 값으로 둔다.
    ticketPrice: controller.hold?.price ?? zone.price,
    bookingFee: performance.bookingFee,
  );
}
