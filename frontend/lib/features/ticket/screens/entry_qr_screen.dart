import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_boundary.dart';
import '../../../core/widgets/poster_image.dart';
import '../../notification/push_notification_scope.dart';
import '../constants.dart';
import '../models/entry_pass.dart';
import '../models/my_ticket.dart';
import '../models/ticket_status.dart';
import '../state/ticket_api_scope.dart';
import '../widgets/qr_countdown_bar.dart';
import '../widgets/qr_notice_box.dart';

/// 입장 QR. 예정 공연 카드의 '입장 QR 보기' 로 들어온다. QR 문자열은 서버가
/// 발급하고(`TicketApi.issueEntryPass`) 수명도 응답에 실려 온다([EntryPass.lifetime]).
/// 수명이 다하면 자동으로 새로 받지 않고 흐린 QR 위에 새로고침 버튼을 둔다 —
/// 검표 직전에 QR 이 바뀌는 순간을 없애기 위해서다. 화면을 벗어나면 타이머를 끈다.
/// 게이트에서 찍히면 서버의 입장 푸시를 받아 곧바로 "입장 완료" 로 바뀐다.
/// 푸시가 빠질 때를 대비해 QR 이 떠 있는 동안 티켓 상태도 주기적으로 확인한다.
class EntryQrScreen extends StatefulWidget {
  const EntryQrScreen({super.key, required this.ticket, this.clock});

  final MyTicket ticket;

  /// 지금 시각을 알려주는 함수. 안 넘기면 기기 시계를 쓴다. 남은 시간을 타이머
  /// 횟수가 아니라 시계로 재는 것은, 앱이 백그라운드로 가면 타이머가 멈춰 돌아왔을
  /// 때 지난 QR 을 "25초 남음" 으로 보이기 때문이다. 테스트가 시간을 돌리는 창구다.
  final DateTime Function()? clock;

  @override
  State<EntryQrScreen> createState() => _EntryQrScreenState();
}

class _EntryQrScreenState extends State<EntryQrScreen> {
  /// 지금 그리고 있는 입장권. 첫 응답이 오기 전에는 없다.
  EntryPass? _pass;

  /// 마지막 틱에 잰 남은 시간과 비율. [_pass] 가 없으면 의미 없는 값이다.
  Duration _remaining = Duration.zero;
  double _progress = 0;

  /// 발급 요청이 나가 있는가. 같은 요청이 겹쳐 나가지 않게 막고, 새로 받는 동안
  /// QR 위에 로딩을 두는 기준이다.
  bool _issuing = false;

  /// 마지막 발급 실패. 다시 시도하면 지운다.
  ApiException? _error;
  bool _alreadyUsed = false;

  Timer? _ticker;

  /// 입장 처리 푸시를 듣는 구독. 화면이 처음 뜰 때 한 번만 건다.
  StreamSubscription<int>? _enteredTicketIds;

  /// 입장 여부 확인 요청이 나가 있는가. 응답이 늦어도 요청이 겹치지 않게 한다.
  bool _checkingEntry = false;

  @override
  void initState() {
    super.initState();
    // 첫 발급. 아직 그린 적이 없으니 setState 없이 값만 두고 요청한다.
    _issuing = true;
    _request();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (timer) => _tick(timer.tick),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enteredTicketIds ??= PushNotificationScope.maybeOf(context)
        ?.enteredTicketIds
        .listen((ticketId) {
          if (ticketId == widget.ticket.ticketId) _markEntered();
        });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _enteredTicketIds?.cancel();
    super.dispose();
  }

  /// 입장 처리가 확인됐다. QR 을 치우고 재시도 없는 "이미 입장한 QR" 안내로
  /// 바꾼다. 더 셀 것이 없으니 타이머도 끈다.
  void _markEntered() {
    if (_alreadyUsed) return;
    _ticker?.cancel();
    setState(() {
      _error = const ApiException(TicketStrings.qrAlreadyUsed, status: 409);
      _issuing = false;
      _alreadyUsed = true;
    });
  }

  DateTime get _now => (widget.clock ?? DateTime.now)();

  /// 새로고침·다시 시도. 요청 중이면 그대로 둔다.
  void _reissue() {
    if (_issuing) return;
    setState(() {
      _issuing = true;
      _error = null;
      _alreadyUsed = false;
    });
    _request();
  }

  /// 서버에 발급을 요청하고 결과를 화면에 반영한다. [_issuing] 을 켜 두고 부른다.
  /// 예매 번호가 아니라 티켓 번호를 넘긴다 — 바꿔 넘기면 엉뚱한 티켓이라 404 다.
  Future<void> _request() async {
    final api = TicketApiScope.of(context);
    try {
      final pass = await api.issueEntryPass(widget.ticket.ticketId);
      // 기다리는 사이 입장 푸시가 먼저 왔으면 새 QR 로 덮지 않는다.
      if (!mounted || _alreadyUsed) return;
      setState(() {
        _pass = pass;
        _measure(pass);
        _issuing = false;
        _alreadyUsed = false;
      });
    } on ApiException catch (e) {
      var displayError = e;
      var alreadyUsed = false;
      if (e.status == 409) {
        try {
          final tickets = await api.fetchMyTickets();
          alreadyUsed = tickets.any(
            (ticket) =>
                ticket.ticketId == widget.ticket.ticketId &&
                ticket.status == TicketStatus.used,
          );
          if (alreadyUsed) {
            displayError = const ApiException(
              TicketStrings.qrAlreadyUsed,
              status: 409,
            );
          }
        } on ApiException {
          // 목록 확인이 실패하면 원래 발급 오류를 보여준다.
        }
      }
      if (!mounted || _alreadyUsed) return;
      setState(() {
        _error = displayError;
        _issuing = false;
        _alreadyUsed = alreadyUsed;
      });
    }
  }

  /// 남은 시간과 비율을 지금 시각으로 다시 잰다. 둘을 한 시각에서 재야
  /// 숫자와 진행 바가 어긋나지 않는다.
  void _measure(EntryPass pass) {
    final now = _now;
    _remaining = pass.remaining(now);
    _progress = pass.progress(now);
  }

  /// 매초. 남은 시간을 다시 재고, [TicketMetrics.qrEntryCheckInterval] 마다
  /// 입장 여부를 확인한다. 0 이 되어도 QR 을 새로 받지는 않는다(클래스 주석).
  /// [tick] 은 타이머가 센 횟수라, 앱이 뒤에 있다 돌아와도 건너뛴 만큼 늘어 있다.
  void _tick(int tick) {
    final pass = _pass;
    // 첫 발급 전이다. 셀 것이 없다.
    if (pass == null) return;
    setState(() => _measure(pass));
    if (tick % TicketMetrics.qrEntryCheckInterval.inSeconds == 0) {
      _checkEntry();
    }
  }

  /// 내 티켓 목록에서 이 티켓이 입장 완료인지 본다. 입장 판단은 상태값으로만
  /// 한다 — 발급 409 는 양도 등록 중 같은 다른 이유로도 온다. QR 이 떠 있을 때만
  /// 묻고, 실패는 조용히 넘긴다. 검표 줄에서 오류 문구가 튀어나오면 안 되고,
  /// 다음 차례에 다시 묻는다.
  Future<void> _checkEntry() async {
    if (_checkingEntry || _error != null) return;
    _checkingEntry = true;
    try {
      final tickets = await TicketApiScope.of(context).fetchMyTickets();
      if (!mounted) return;
      final entered = tickets.any(
        (ticket) =>
            ticket.ticketId == widget.ticket.ticketId &&
            ticket.status == TicketStatus.used,
      );
      if (entered) _markEntered();
    } on ApiException {
      // 다음 확인에서 다시 묻는다.
    } finally {
      _checkingEntry = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(TicketStrings.qrScreenTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(TicketMetrics.horizontalPadding),
          children: [
            _Header(ticket: widget.ticket),
            const SizedBox(height: 20),
            _QrPanel(
              pass: _pass,
              remaining: _remaining,
              progress: _progress,
              issuing: _issuing,
              error: _error,
              alreadyUsed: _alreadyUsed,
              onRefresh: _reissue,
            ),
            const SizedBox(height: 16),
            const QrNoticeBox(),
          ],
        ),
      ),
    );
  }
}

/// 공연 제목과 일시·좌석·장소, 오른쪽에 포스터.
class _Header extends StatelessWidget {
  const _Header({required this.ticket});

  final MyTicket ticket;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ticket.title,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _InfoLine(
                label: TicketStrings.qrDate,
                value: ticket.startAt == null
                    ? TicketStrings.dateUndecided
                    : formatPerformedAtWithWeekday(ticket.startAt!),
              ),
              _InfoLine(label: TicketStrings.qrSeat, value: ticket.seatLabel),
              _InfoLine(label: TicketStrings.qrVenue, value: ticket.venueName),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: TicketMetrics.qrPosterWidth,
          height: TicketMetrics.qrPosterHeight,
          child: PosterImage.network(
            url: ticket.posterImageUrl,
            borderRadius: TicketMetrics.posterRadius,
            decodeWidth: TicketMetrics.qrPosterWidth,
          ),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text('$label: $value', style: style),
    );
  }
}

/// QR 과 남은 시간을 담은 흰 상자. QR 자리는 늘 정사각 한 칸이라(로딩·실패·QR
/// 이 모두 그 칸에 들어간다) 응답이 와도 아래 안내 상자가 뛰지 않는다. 남은
/// 시간과 안내는 QR 이 있을 때만 그린다 — 없을 때 `00:00` 을 보이면 만료로 읽힌다.
class _QrPanel extends StatelessWidget {
  const _QrPanel({
    required this.pass,
    required this.remaining,
    required this.progress,
    required this.issuing,
    required this.error,
    required this.alreadyUsed,
    required this.onRefresh,
  });

  final EntryPass? pass;
  final Duration remaining;
  final double progress;
  final bool issuing;
  final ApiException? error;
  final bool alreadyUsed;

  /// 새로고침 버튼과 다시 시도 버튼이 함께 쓴다. 둘 다 "새로 받기" 다.
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pass = this.pass;
    final error = this.error;
    final expired = remaining == Duration.zero;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(TicketMetrics.cardRadius),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // QR 은 정사각이어야 읽힌다. 폭에 맞춰 높이를 따라가게 둔다.
          AspectRatio(
            aspectRatio: 1,
            child: error != null
                ? _IssueError(
                    message: error.message,
                    onRetry: alreadyUsed ? null : onRefresh,
                  )
                : pass == null
                ? const Center(child: CircularProgressIndicator())
                : _QrImage(
                    pass: pass,
                    expired: expired,
                    refreshing: issuing,
                    onRefresh: onRefresh,
                  ),
          ),
          if (error == null && pass != null) ...[
            const SizedBox(height: 20),
            QrCountdownBar(remaining: remaining, progress: progress),
            const SizedBox(height: 12),
            Text(
              expired
                  ? TicketStrings.qrExpiredNotice
                  : TicketStrings.qrValidFor(pass.lifetime.inSeconds),
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 서버가 준 문자열을 그대로 그린 QR. 만료되면 반투명 흰색으로 덮고 가운데
/// 새로고침 버튼을 둔다 — 회색이 된 QR 은 "지난 것" 으로 읽히고 대비가 낮아져
/// 검표기도 잘 안 읽는다. 새로 받는 동안은 같은 자리에 로딩이 돈다.
class _QrImage extends StatelessWidget {
  const _QrImage({
    required this.pass,
    required this.expired,
    required this.refreshing,
    required this.onRefresh,
  });

  final EntryPass pass;
  final bool expired;
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        QrImageView(
          // 값이 바뀌면 위젯도 새것으로 본다. `QrImageView` 는 그린 코드를 안에
          // 들고 있어 키가 같으면 새 값이 반영되지 않을 수 있다. 테스트도 이 키로 본다.
          key: ValueKey(pass.token),
          data: pass.token,
          // 검표기가 읽는 그림이라 배경은 흰색, 전경은 검정으로 고정한다.
          // 브랜드 초록으로 그리면 대비가 떨어져 인식률이 나빠진다.
          backgroundColor: Colors.white,
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: Colors.black,
          ),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: Colors.black,
          ),
          // 여백(quiet zone)이 없으면 리더기가 코드 경계를 못 찾는다.
          padding: const EdgeInsets.all(12),
        ),
        if (expired || refreshing)
          ColoredBox(
            color: AppColors.surface.withValues(
              alpha: TicketMetrics.qrExpiredOverlayOpacity,
            ),
            child: Center(
              child: refreshing
                  ? const CircularProgressIndicator()
                  : IconButton.filled(
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh),
                      iconSize: TicketMetrics.qrRefreshIconSize,
                      tooltip: TicketStrings.qrRefresh,
                    ),
            ),
          ),
      ],
    );
  }
}

/// 발급에 실패했을 때 QR 자리에 들어가는 안내. 입장 완료면 재시도를 숨긴다.
/// [AsyncBoundary] 는 Future 하나의 성공·실패를 가르는 틀이라 같은 요청을 몇 번이고
/// 다시 보내는 이 화면과 맞지 않아, 버튼 문구만 같은 상수를 쓴다.
class _IssueError extends StatelessWidget {
  const _IssueError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              child: const Text(AsyncBoundary.retryLabel),
            ),
          ],
        ],
      ),
    );
  }
}
