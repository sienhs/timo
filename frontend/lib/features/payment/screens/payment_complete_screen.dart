import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/timo_mascot.dart';
import '../../../routes/app_routes.dart';
import '../../ticket/models/reservation_detail.dart';
import '../../ticket/state/ticket_api_scope.dart';
import '../constants.dart';
import '../models/ticket_order.dart';
import '../widgets/booking_detail_card.dart';
import '../widgets/issue_status_badge.dart';
import '../widgets/poster_avatar.dart';
import '../widgets/primary_action_button.dart';
import '../widgets/ticket_issuing_view.dart';

/// 결제 완료 화면. 결제 결과와 예약 정보를 보여주고, 티켓 발행이 끝나기를
/// 기다린다. 서버가 뒤에서 잔액을 차감하고 NFT 를 발행하는 동안 몇 초마다 주문
/// 상세를 다시 물어 배지를 바꾸고, 그때까지는 연출([TicketIssuingView])만 보여
/// 준다. [pollTimeout] 안에 답이 없으면 묻기를 그만두고 화면을 연다.
class PaymentCompleteScreen extends StatefulWidget {
  const PaymentCompleteScreen({
    super.key,
    required this.order,
    this.reservationId,
    this.pollInterval = PaymentConstants.issuePollInterval,
    this.pollTimeout = PaymentConstants.issuePollTimeout,
  });

  final TicketOrder order;

  /// 발행 상태를 물어볼 예매 번호. 예매 흐름 밖에서 열렸으면 서버에 만든 주문이
  /// 없어 null 이고, 그때는 묻지 않고 "발행 중" 배지만 보여 준다.
  final int? reservationId;

  /// 다시 묻는 주기와 그만두는 시점. 테스트가 줄여서 넘긴다.
  final Duration pollInterval;
  final Duration pollTimeout;

  @override
  State<PaymentCompleteScreen> createState() => _PaymentCompleteScreenState();
}

class _PaymentCompleteScreenState extends State<PaymentCompleteScreen> {
  TicketIssueStatus _status = TicketIssueStatus.issuing;

  /// 되묻기 주기.
  Timer? _timer;

  /// 그만 묻는 시점. 되묻기와 따로 시계로 센다. 물어본 횟수로 세면 서버가 늦어
  /// 요청이 물려 있는 동안([_polling]) 주기를 건너뛰어 실제보다 한참 늦게 잡힌다.
  Timer? _deadline;

  /// 요청이 나가 있는 동안 참. 서버가 늦어도 같은 질문을 겹쳐 보내지 않는다.
  bool _polling = false;

  /// 물어보기를 그만뒀는데 아직 발행 중인가. 실패와 다르다 — 발행은 서버에서
  /// 그대로 진행 중이고, 이 화면만 더 기다릴 방법이 없을 뿐이다.
  bool _gaveUp = false;

  @override
  void initState() {
    super.initState();
    if (widget.reservationId != null) {
      _timer = Timer.periodic(widget.pollInterval, (_) => _poll());
      _deadline = Timer(widget.pollTimeout, _giveUp);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _deadline?.cancel();
    super.dispose();
  }

  /// 기다릴 만큼 기다렸다. 되묻기를 접고 화면을 연다. 실패로 그리지 않는다 —
  /// 발행은 서버에서 그대로 진행 중이고 결과는 내 티켓에 남는다.
  void _giveUp() {
    _timer?.cancel();
    if (!mounted || _status != TicketIssueStatus.issuing) return;
    setState(() => _gaveUp = true);
  }

  Future<void> _poll() async {
    final reservationId = widget.reservationId;
    if (reservationId == null || _polling) return;

    _polling = true;
    try {
      final detail = await TicketApiScope.of(
        context,
      ).fetchReservation(reservationId);
      if (!mounted) return;
      if (detail.issueStatus != TicketIssueStatus.issuing) {
        // 그만둘 시점을 기다리던 시계도 접는다. 결과가 나왔으니 잴 것이 없다.
        _timer?.cancel();
        _deadline?.cancel();
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

  void _goHome() => Navigator.popUntil(context, (route) => route.isFirst);

  /// 발행이 끝나기를 기다리는 중인가. 참이면 연출만 그린다. 예매 번호가 없으면
  /// 물을 데가 없어 기다려도 바뀌지 않으므로 바로 연다.
  bool get _waiting =>
      widget.reservationId != null &&
      !_gaveUp &&
      _status == TicketIssueStatus.issuing;

  /// 기다릴 만큼 기다렸는데 아직 발행 중인가. 연출은 그대로 두고 문구와 진행 바
  /// 색만 바꾸며, 여기서만 버튼을 붙여 나갈 길을 낸다.
  bool get _delayed => _gaveUp && _status == TicketIssueStatus.issuing;

  /// 실패만 제목이 다르다. 발행 중(지연)과 완료는 결제가 끝났다는 사실이 아직
  /// 유효하다.
  String get _title => _status == TicketIssueStatus.failed
      ? PaymentConstants.issueFailedTitle
      : PaymentConstants.completeTitle;

  String get _description => switch (_status) {
    TicketIssueStatus.issuing => PaymentConstants.issuingDescription,
    TicketIssueStatus.issued => PaymentConstants.issuedDescription,
    TicketIssueStatus.failed => PaymentConstants.issueFailedDescription,
  };

  @override
  Widget build(BuildContext context) {
    final ceremony = _waiting || _delayed;

    return Scaffold(
      // 연출이 도는 동안에는 흰 바탕으로 바꾼다. 클립의 배경이 흰색이라 완료
      // 화면의 연회색 위에 그대로 올리면 흰 사각형이 떠 보인다.
      backgroundColor: ceremony ? Colors.white : PaymentColors.page,
      body: SafeArea(child: ceremony ? _buildCeremony() : _buildResult()),
    );
  }

  /// 기다리는 화면. 지연일 때만 아래에 버튼이 붙는다. 지연으로 넘어가도 같은
  /// 짜임을 유지한다 — 연출을 감싸는 모양이 바뀌면 위젯이 자리를 잃어 영상이
  /// 처음부터 다시 시작한다.
  Widget _buildCeremony() {
    return Column(
      children: [
        Expanded(child: TicketIssuingView(delayed: _delayed)),
        if (_delayed) Padding(padding: _actionPadding, child: _buildActions()),
      ],
    );
  }

  /// 버튼 자리의 여백. 결과 화면과 지연된 연출이 같은 자리에 버튼을 세운다.
  static const _actionPadding = EdgeInsets.fromLTRB(16, 0, 16, 8);

  /// 결과 화면의 안쪽 여백. 가운데 정렬 계산에도 쓰여 상수로 둔다.
  static const _resultPadding = EdgeInsets.fromLTRB(16, 32, 16, 16);

  Widget _buildResult() {
    return Column(
      children: [
        // 내용이 짧으면 가운데로 모은다. 위에서부터 쌓으면 카드 아래로 빈 자리가
        // 한 뭉텅이 남는다. 길어지면 여느 스크롤처럼 위에서부터 흐른다.
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: _resultPadding,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - _resultPadding.vertical,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildHero(),
                    const SizedBox(height: 20),
                    Text(
                      _title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: PaymentColors.value,
                      ),
                    ),
                    // 배지는 아직 발행 중일 때만 남는다. 끝난 상태는 마스코트가
                    // 맡았고, 배지까지 두면 같은 말을 두 번 하는 셈이다.
                    if (_status == TicketIssueStatus.issuing) ...[
                      const SizedBox(height: 12),
                      IssueStatusBadge(status: _status),
                    ],
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
                    BookingDetailCard(
                      order: widget.order,
                      refunding: _status == TicketIssueStatus.failed,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(padding: _actionPadding, child: _buildActions()),
      ],
    );
  }

  /// 결과를 한눈에 알리는 그림. 끝난 상태는 마스코트가 맡는다(완료는 따봉, 실패는
  /// 울음) — 같은 자리 같은 크기라 화면이 흔들리지 않는다. 아직 발행 중이면
  /// 공연 포스터를 세우고 상태는 배지가 말한다.
  Widget _buildHero() => switch (_status) {
    TicketIssueStatus.issued => const TimoMascot.cheer(
      size: PaymentConstants.resultMascotSize,
    ),
    TicketIssueStatus.failed => const TimoMascot.sad(
      size: PaymentConstants.resultMascotSize,
    ),
    TicketIssueStatus.issuing => PosterAvatar(url: widget.order.posterUrl),
  };

  /// 발행이 어떻게 끝났느냐에 따라 내어 주는 길이 다르다. 실패했으면 티켓이
  /// 없으니 '티켓 보러 가기'를 내지 않고 홈만 주요 버튼으로 세운다.
  Widget _buildActions() {
    if (_status == TicketIssueStatus.failed) {
      return Column(
        children: [
          PrimaryActionButton(
            label: PaymentConstants.goHomeLabel,
            onPressed: _goHome,
          ),
          const SizedBox(height: 12),
        ],
      );
    }

    return Column(
      children: [
        PrimaryActionButton(
          label: PaymentConstants.viewTicketLabel,
          onPressed: _openMyTickets,
        ),
        TextButton(
          onPressed: _goHome,
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
    );
  }
}
