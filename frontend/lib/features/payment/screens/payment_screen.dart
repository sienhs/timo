import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/server_errors.dart';
import '../../../core/widgets/error_snack_bar.dart';
import '../../../routes/app_routes.dart';
import '../../ticket/state/ticket_api_scope.dart';
import '../constants.dart';
import '../models/order_target.dart';
import '../models/placed_order.dart';
import '../models/ticket_order.dart';
import '../widgets/hold_countdown_button.dart';
import '../widgets/order_summary_card.dart';

/// 결제 화면. 주문 요약을 확인하고 결제를 진행한다.
///
/// 주문 정보는 주입받으므로 이 화면은 값의 출처(서버·더미)를 알지 않는다.
///
/// **'결제하기' 는 서버에 주문을 만든다**(`POST /reservations`). 결제 수단을
/// 고르는 단계는 없다 — 결제는 예치 잔액(버섯) 차감 한 가지뿐이라, 서버가 이
/// 요청 안에서 좌석 배정과 차감을 끝낸다. 온체인 티켓 발행은 그 뒤 서버가
/// 이어 가고, 완료 화면이 그 진행을 보여 준다.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.order,
    this.holdRemaining,
    this.target,
  });

  final TicketOrder order;

  /// 잡아 둔 좌석이 풀리기까지 남은 시간. 화면에 들어온 시점 기준이다.
  ///
  /// 계산은 예매 쪽(`SeatHold.remainingFrom`)이 한다. 이 화면은 받은 시간만큼
  /// 세면 된다. 예매 흐름 밖에서 열렸으면(디자인 확인·테스트) null 이고,
  /// 그때는 규약값인 5분으로 센다.
  final Duration? holdRemaining;

  /// 서버에 주문을 만들 때 보내는 공연·좌석 번호.
  ///
  /// 예매 흐름 밖에서 열렸으면(디자인 확인 · 화면 단위 테스트) 잡아 둔 자리가
  /// 없어 null 이고, 그때 결제하기는 서버를 부르지 않고 완료 화면만 보여 준다.
  final OrderTarget? target;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  /// 주문 요청이 나가 있는 동안 참. 결제하기 버튼을 잠가 둔다.
  ///
  /// 두 번 눌러도 서버가 두 번째는 409 로 거절하지만, 첫 요청의 응답을
  /// 기다리는 동안 버튼이 멀쩡해 보이면 사용자는 눌리지 않았다고 생각한다.
  bool _submitting = false;

  Future<void> _pay() async {
    final target = widget.target;
    if (target == null) {
      // 예매 흐름 밖에서 열린 화면이다. 서버에 만들 주문이 없으니 완료 화면만
      // 보여 준다.
      _showComplete(reservationId: null);
      return;
    }

    setState(() => _submitting = true);
    try {
      final detail = await TicketApiScope.of(
        context,
      ).createReservation(concertId: target.concertId, seatId: target.seatId);
      if (!mounted) return;
      _showComplete(reservationId: detail.reservationId);
    } on ApiException catch (e) {
      if (mounted) _onPayFailed(e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// 완료 화면으로 **교체** 이동한다. 뒤로 가기로 결제 화면에 돌아와 같은
  /// 자리를 다시 결제하는 일이 없게 한다.
  ///
  /// 주문이 만들어졌으면 결과로 true 를 남긴다. 이 화면을 띄운 좌석 화면이 그
  /// 값을 보고 잡아 둔 자리를 풀지 않는다 — 서버가 선점을 주문으로 바꿨으니
  /// 여기서 풀면 안 된다.
  void _showComplete({required int? reservationId}) {
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.paymentComplete,
      result: reservationId != null,
      arguments: PlacedOrder(order: widget.order, reservationId: reservationId),
    );
  }

  /// 서버가 주문을 거절했거나 요청이 닿지 못했다.
  ///
  /// 이 자리로는 더 진행할 수 없는 거절(선점 만료 · 남의 선점 · 이미 산 공연 ·
  /// 판매 중이 아닌 공연 · 로그인 풀림)은 사유를 띄우고 좌석 화면으로 돌아간다.
  /// 좌석 화면이 잡아 둔 자리를 정리하고 배치도를 새로 받는다. 스낵바는
  /// MaterialApp 의 ScaffoldMessenger 가 띄우므로 이 화면을 닫아도 남아 있다.
  ///
  /// 인터넷 끊김 · 서버 오류(5xx)는 이 화면에 남아 다시 누를 수 있게 둔다.
  /// 자리는 아직 잡혀 있다.
  void _onPayFailed(ApiException e) {
    final status = e.status;
    showErrorSnackBar(context, _failureMessage(e));
    if (status != null && status >= 400 && status < 500) {
      Navigator.pop(context);
    }
  }

  /// 거절 사유를 화면 문구로 바꾼다.
  ///
  /// **상태 코드만으로는 못 가른다.** 선점 만료·1인 1매·판매 중이 아닌 공연이
  /// 전부 409 라, 서버가 실어 준 예외 이름을 본다.
  ///
  /// 서버 문구를 그대로 쓰지 않는다. 우리가 아는 사유에는 `(concertId=3)` 같은
  /// 디버깅용 꼬리가 붙어 있고, 문구가 좌석 화면의 것과 따로 놀면 같은 이유로
  /// 두 번 막혔을 때 다른 일이 일어난 것처럼 읽힌다.
  ///
  /// 모르는 실패는 서버 문구를 그대로 보여준다. 우리가 문구를 붙이지 못한
  /// 거절까지 뭉뚱그리면 원인을 알 길이 없어진다(api-response-convention).
  String _failureMessage(ApiException e) {
    if (e.status == 401) return PaymentConstants.loginRequired;

    return switch (e.exceptionName) {
      BookingServerErrors.seatNotHeld => PaymentConstants.holdExpired,
      BookingServerErrors.seatHoldNotOwned => PaymentConstants.holdNotOwned,
      BookingServerErrors.alreadyReserved => PaymentConstants.alreadyReserved,
      BookingServerErrors.concertNotOnSale => PaymentConstants.concertNotOnSale,
      _ => e.message,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PaymentColors.page,
      appBar: AppBar(
        backgroundColor: PaymentColors.card,
        surfaceTintColor: PaymentColors.card,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: PaymentColors.value,
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          PaymentConstants.payScreenTitle,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: PaymentColors.value,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: OrderSummaryCard(order: widget.order),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Text(
                    PaymentConstants.holdWarning,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: PaymentColors.warning,
                    ),
                  ),
                  const SizedBox(height: 10),
                  HoldCountdownButton(
                    duration:
                        widget.holdRemaining ?? PaymentConstants.holdDuration,
                    onPressed: _submitting ? null : _pay,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
