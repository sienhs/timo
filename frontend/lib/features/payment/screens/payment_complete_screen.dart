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
/// 기다린다.
///
/// 주문이 확정된 순간 티켓은 아직 체인에 올라가는 중이다. 서버가 뒤에서 잔액을
/// 차감하고 NFT 를 발행하는데, 이 화면은 그 결과를 알려 주는 방법이 없어
/// (알림 없음) 몇 초마다 주문 상세를 다시 물어 배지를 바꾼다.
///
/// 그 기다리는 동안은 **연출만 보여 준다**([TicketIssuingView]). 예약 정보도
/// 버튼도 내지 않는다 — 아직 없는 티켓을 보러 가라고 할 수 없고, 결과를 못 본
/// 채 홈으로 나가게 둘 이유도 없다. 발행이 끝나야 이 화면의 나머지가 열린다.
///
/// 다만 끝나지 **않는** 길도 있다. 서버가 [PaymentCompleteScreen.pollTimeout]
/// 안에 답을 못 주면 묻기를 그만두는데, 그때까지 연출만 돌리면 나갈 곳 없는
/// 화면이 된다. 그래서 그만 묻는 순간에도 화면을 열어 준다 — 발행 중 그대로
/// 두되 문구를 바꾸고 버튼을 낸다.
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

  /// 되묻기 주기.
  Timer? _timer;

  /// 그만 묻는 시점. 되묻기와 **따로** 센다.
  ///
  /// 물어본 횟수로 세면 안 된다. 서버가 늦어 요청이 물려 있으면([_polling])
  /// 그동안의 주기는 세지 않고 넘어가므로, 횟수 × 주기가 실제로 흐른 시간보다
  /// 한참 모자라게 잡힌다. 응답이 매번 느린 날에는 [PaymentCompleteScreen.pollTimeout]
  /// 이 두세 배로 늘어나고, 그 시간 내내 연출에는 누를 것이 없다. 나갈 길이
  /// 열리는 시점만큼은 시계로 재야 한다.
  Timer? _deadline;

  /// 요청이 나가 있는 동안 참. 서버가 늦어도 같은 질문을 겹쳐 보내지 않는다.
  bool _polling = false;

  /// 물어보기를 그만뒀는데 아직 발행 중인가.
  ///
  /// 실패와 다르다. 발행은 서버에서 그대로 진행 중이고 결과는 알림과 내 티켓에
  /// 남는다 — 이 화면만 더 기다릴 방법이 없을 뿐이다. 그래서 실패로 그리지
  /// 않고, 대신 연출을 걷어 나갈 길을 내어 준다.
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

  /// 기다릴 만큼 기다렸다. 되묻기를 접고 화면을 연다.
  ///
  /// 실패로 그리지 않는다 — 발행은 서버에서 그대로 진행 중이고, 결과는 내
  /// 티켓에 남는다. 이 화면만 더 기다릴 방법이 없을 뿐이다.
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

  /// 발행이 끝나기를 기다리는 중인가. 참이면 연출만 그린다.
  ///
  /// 예매 번호가 없으면(예매 흐름 밖 · 화면 단위 테스트) 물을 데가 없어 기다려도
  /// 상태가 바뀌지 않는다. 기다리는 시늉만 하는 연출에 가두지 않고 바로 연다.
  bool get _waiting =>
      widget.reservationId != null &&
      !_gaveUp &&
      _status == TicketIssueStatus.issuing;

  /// 기다릴 만큼 기다렸는데 아직 발행 중인가.
  ///
  /// 연출은 그대로 둔다 — 발행은 정말 진행 중이라 결과 화면으로 넘기면 끝난
  /// 것처럼 읽힌다. 대신 문구와 진행 바 색을 바꾸고, 여기서만 버튼을 붙여
  /// 나갈 길을 낸다.
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
      // 연출이 도는 동안에는 흰 바탕으로 바꾼다. 클립의 배경을 흰색까지 눌러
      // 두어서(`docs/video-assets.md`), 완료 화면의 연회색 위에 그대로 올리면
      // 흰 사각형이 떠 보인다.
      backgroundColor: ceremony ? Colors.white : PaymentColors.page,
      body: SafeArea(child: ceremony ? _buildCeremony() : _buildResult()),
    );
  }

  /// 기다리는 화면. 지연일 때만 아래에 버튼이 붙는다.
  ///
  /// 기다리는 중에는 누를 것을 두지 않는 것이 이 화면의 규칙이지만, 언제
  /// 끝날지 더는 알 수 없게 된 순간에도 그 규칙을 지키면 나갈 길이 없어진다.
  /// 지연으로 넘어가도 **같은 짜임**을 유지한다. 연출을 감싸는 모양이 바뀌면
  /// 위젯이 자리를 잃어 영상이 처음부터 다시 시작한다 — 2분을 기다린 사람에게
  /// 클립이 되감기는 것으로 보인다.
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
        // 내용이 짧으면 가운데로 모은다. 위에서부터 쌓으면 마스코트가 화면
        // 꼭대기에 붙고 카드 아래로 빈 자리가 한 뭉텅이 남아, 그림이 화면
        // 밖으로 밀려나는 것처럼 보인다. 길어지면(글자 크기를 키운 기기 등)
        // 그때는 여느 스크롤처럼 위에서부터 흐른다.
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

  /// 결과를 한눈에 알리는 그림.
  ///
  /// 끝난 상태는 **마스코트가 맡는다**. 작은 알약 배지로 '발행 완료' 를 알리는
  /// 것보다, 결제를 막 끝낸 사람에게는 따봉을 든 너구리 한 마리가 훨씬 잘
  /// 읽힌다. 실패는 우는 너구리다 — 같은 자리 같은 크기라 화면이 흔들리지
  /// 않으면서 결과만 바뀐다. 무엇이 어떻게 됐는지는 바로 아래 제목과 문구가
  /// 글로도 말하므로, 그림만 아는 정보는 없다.
  ///
  /// 아직 발행 중이면(오래 걸려 이 화면을 연 경우) 따봉도 울음도 이르다.
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

  /// 발행이 어떻게 끝났느냐에 따라 내어 주는 길이 다르다.
  ///
  /// 실패했으면 티켓이 없으니 '티켓 보러 가기'를 내지 않는다 — 누르면 빈
  /// 목록으로 보내는 셈이다. 남은 길이 홈뿐이라 그 하나를 주요 버튼으로 세운다.
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
