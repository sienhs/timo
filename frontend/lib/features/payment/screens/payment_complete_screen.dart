import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../routes/app_routes.dart';
import '../../ticket/models/reservation_detail.dart';
import '../../ticket/state/ticket_api_scope.dart';
import '../constants.dart';
import '../models/ticket_order.dart';
import '../widgets/booking_detail_card.dart';
import '../widgets/issue_status_badge.dart';
import '../widgets/poster_avatar.dart';
import '../widgets/primary_action_button.dart';

/// 결제 완료 화면. 결제 결과와 예약 정보를 보여주고, 티켓 발행이 끝나기를
/// 기다린다.
///
/// 주문이 확정된 순간 티켓은 아직 체인에 올라가는 중이다. 서버가 뒤에서 잔액을
/// 차감하고 NFT 를 발행하는데, 이 화면은 그 결과를 알려 주는 방법이 없어
/// (알림 없음) 몇 초마다 주문 상세를 다시 물어 배지를 바꾼다.
class PaymentCompleteScreen extends StatefulWidget {
  const PaymentCompleteScreen({
    super.key,
    required this.order,
    this.reservationId,
    this.pollInterval = PaymentConstants.issuePollInterval,
    this.pollTimeout = PaymentConstants.issuePollTimeout,
  });

  final TicketOrder order;

  /// 발행 상태를 물어볼 예매 번호.
  ///
  /// 예매 흐름 밖에서 열렸으면(디자인 확인 · 화면 단위 테스트) 서버에 만든
  /// 주문이 없어 null 이고, 그때는 묻지 않고 "발행 중" 배지만 보여 준다.
  final int? reservationId;

  /// 다시 묻는 주기와 그만두는 시점. 테스트가 줄여서 넘긴다.
  final Duration pollInterval;
  final Duration pollTimeout;

  @override
  State<PaymentCompleteScreen> createState() => _PaymentCompleteScreenState();
}

class _PaymentCompleteScreenState extends State<PaymentCompleteScreen> {
  TicketIssueStatus _status = TicketIssueStatus.issuing;
  Timer? _timer;

  /// 지금까지 몇 번 물었는가. [PaymentCompleteScreen.pollTimeout] 을 넘기면
  /// 그만 묻는다. 시계 대신 횟수로 세는 이유는 테스트에서 시간을 가짜로
  /// 돌리기 때문이다.
  int _polls = 0;

  /// 요청이 나가 있는 동안 참. 서버가 늦어도 같은 질문을 겹쳐 보내지 않는다.
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    if (widget.reservationId != null) {
      _timer = Timer.periodic(widget.pollInterval, (_) => _poll());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    final reservationId = widget.reservationId;
    if (reservationId == null || _polling) return;

    _polls++;
    if (widget.pollInterval * _polls >= widget.pollTimeout) {
      // 마지막으로 한 번 더 묻고 그만둔다.
      _timer?.cancel();
    }

    _polling = true;
    try {
      final detail = await TicketApiScope.of(
        context,
      ).fetchReservation(reservationId);
      if (!mounted) return;
      if (detail.issueStatus != TicketIssueStatus.issuing) {
        _timer?.cancel();
        setState(() => _status = detail.issueStatus);
      }
    } on ApiException {
      // 한 번 못 물은 것은 다음 주기에 다시 묻는다. 인터넷이 잠깐 끊겼다고
      // 실패로 그리면 거짓말이다 — 발행은 서버에서 그대로 진행되고 있다.
    } finally {
      _polling = false;
    }
  }

  /// 내 티켓으로 간다. 결제 흐름 화면들(구역 · 좌석 · 완료)은 다 닫고 홈 위에
  /// 내 티켓을 올려, 거기서 뒤로 가면 홈이 나오게 한다.
  void _openMyTickets() {
    final navigator = Navigator.of(context);
    navigator.popUntil((route) => route.isFirst);
    navigator.pushNamed(AppRoutes.myTickets);
  }

  String get _description => switch (_status) {
    TicketIssueStatus.issuing => PaymentConstants.issuingDescription,
    TicketIssueStatus.issued => PaymentConstants.issuedDescription,
    TicketIssueStatus.failed => PaymentConstants.issueFailedDescription,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PaymentColors.page,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                child: Column(
                  children: [
                    PosterAvatar(url: widget.order.posterUrl),
                    const SizedBox(height: 20),
                    const Text(
                      PaymentConstants.completeTitle,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: PaymentColors.value,
                      ),
                    ),
                    const SizedBox(height: 12),
                    IssueStatusBadge(status: _status),
                    const SizedBox(height: 14),
                    Text(
                      _description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: PaymentColors.label,
                      ),
                    ),
                    const SizedBox(height: 24),
                    BookingDetailCard(order: widget.order),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                children: [
                  PrimaryActionButton(
                    label: PaymentConstants.viewTicketLabel,
                    onPressed: _openMyTickets,
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.popUntil(context, (route) => route.isFirst),
                    child: const Text(
                      PaymentConstants.goHomeLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: PaymentColors.value,
                      ),
                    ),
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
