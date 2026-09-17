import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_boundary.dart';
import '../../../core/widgets/poster_image.dart';
import '../constants.dart';
import '../models/entry_pass.dart';
import '../models/my_ticket.dart';
import '../state/ticket_api_scope.dart';
import '../widgets/qr_countdown_bar.dart';
import '../widgets/qr_notice_box.dart';

/// 입장 QR. 예정 공연 카드의 '입장 QR 보기' 로 들어온다.
///
/// QR 문자열은 **서버가 발급한다**([TicketApi.issueEntryPass]). 들어오면 한 장
/// 받아 그린다. 몇 초짜리인지는 서버가 응답에 실어 주므로([EntryPass.lifetime])
/// 이 화면은 그 값을 셀 뿐 30 이라는 숫자를 모른다.
///
/// 수명이 다하면 **자동으로 새로 받지 않는다.** QR 을 흐리게 하고 가운데
/// 새로고침 버튼을 두어, 누르면 새로 받는다(사용자 결정, 2026-09-20 — 은행·
/// 출입 QR 앱들이 흔히 쓰는 방식). 자동으로 계속 받으면 화면을 켜 둔 채 줄을
/// 서는 동안 30초마다 요청이 나가고, 검표 직전에 QR 이 바뀌어 검표기가 읽던
/// 값이 무효가 되는 순간이 생긴다. 새로 받는 시점을 사용자가 정하면 둘 다 없다.
///
/// 초마다 다시 그리는 것은 카운트다운과 진행 바뿐이고, QR 은 새로 받았을 때만
/// 바뀐다.
///
/// 새로 받는 동안은 흐린 QR 위에 로딩을 둔다. 응답은 보통 1초 안에 오는데
/// 그때마다 QR 자리가 하얗게 비었다 채워지면 화면이 깜빡인다. 흐린 QR 은 이미
/// 만료된 것이라 검표기가 읽어도 통과하지 않는다.
///
/// 실패하면 QR 자리에 서버 문구와 다시 시도를 둔다. 사유(입장 시간대 밖, 발행
/// 전, 양도 등록 중 …)는 서버만 알아 문구를 그대로 쓴다.
///
/// 화면을 벗어나면 타이머를 끈다. 켜 둔 채로 두면 목록으로 돌아간 뒤에도 매초
/// 깨어나 배터리를 먹는다.
///
/// 하단 바를 달지 않는다. 시안에도 없다 — 입장하는 순간에 홈으로 새는 길을
/// 열어 둘 이유가 없다.
class EntryQrScreen extends StatefulWidget {
  const EntryQrScreen({super.key, required this.ticket, this.clock});

  final MyTicket ticket;

  /// 지금 시각을 알려주는 함수. 안 넘기면 기기 시계를 쓴다.
  ///
  /// 남은 시간을 타이머가 몇 번 울렸는지로 세지 않고 시계로 재는 이유: 앱이
  /// 백그라운드로 가면 타이머가 멈춘다. 횟수로 세면 다시 돌아왔을 때 10분 지난
  /// QR 을 "25초 남음" 으로 보여주게 된다. 시계로 재면 돌아온 첫 틱에 0 으로
  /// 잡혀 곧바로 만료 상태가 된다.
  ///
  /// 그래서 시계를 밖에서 받을 수 있게 열어 둔다. 테스트가 시간을 돌리는 창구다.
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

  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // 첫 발급. 아직 그린 적이 없으니 setState 없이 값만 두고 요청한다.
    _issuing = true;
    _request();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  DateTime get _now => (widget.clock ?? DateTime.now)();

  /// 새로고침·다시 시도. 요청 중이면 그대로 둔다.
  void _reissue() {
    if (_issuing) return;
    setState(() {
      _issuing = true;
      _error = null;
    });
    _request();
  }

  /// 서버에 발급을 요청하고 결과를 화면에 반영한다. [_issuing] 을 켜 두고 부른다.
  ///
  /// 예매 번호가 아니라 **티켓 번호**를 넘긴다. QR 은 발행된 티켓 한 장에 붙는
  /// 것이고, 둘은 다른 값이라 바꿔 넘기면 엉뚱한 티켓을 가리켜 404 가 난다.
  Future<void> _request() async {
    final api = TicketApiScope.of(context);
    try {
      final pass = await api.issueEntryPass(widget.ticket.ticketId);
      if (!mounted) return;
      setState(() {
        _pass = pass;
        _measure(pass);
        _issuing = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _issuing = false;
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

  /// 매초. 남은 시간만 다시 잰다. 0 이 되면 그 값이 곧 만료 상태다 — 여기서
  /// 서버를 다시 부르지 않는다(클래스 주석).
  void _tick() {
    final pass = _pass;
    // 첫 발급 전이다. 셀 것이 없다.
    if (pass == null) return;
    setState(() => _measure(pass));
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

/// QR 과 남은 시간을 담은 흰 상자.
///
/// QR 자리는 늘 정사각 한 칸이다. 처음 받는 동안은 로딩, 실패하면 문구와
/// 다시 시도, 받았으면 QR 이 그 칸에 들어간다. 칸 크기를 상태마다 다르게 두면
/// 응답이 올 때마다 아래 안내 상자가 위아래로 뛴다.
///
/// 남은 시간과 안내는 QR 이 있을 때만 그린다. 아직 받지 못했거나 실패한
/// 상태에서 `00:00` 과 빈 진행 바를 보이면 "만료됐다" 로 읽힌다. 만료됐을 때는
/// 안내 문구가 "새로고침을 누르라" 로 바뀐다 — 흐린 QR 만으로는 무엇을 해야
/// 하는지 알 수 없다.
class _QrPanel extends StatelessWidget {
  const _QrPanel({
    required this.pass,
    required this.remaining,
    required this.progress,
    required this.issuing,
    required this.error,
    required this.onRefresh,
  });

  final EntryPass? pass;
  final Duration remaining;
  final double progress;
  final bool issuing;
  final ApiException? error;

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
                ? _IssueError(message: error.message, onRetry: onRefresh)
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

/// 서버가 준 문자열을 그대로 그린 QR.
///
/// 만료되면 흐리게 덮고 가운데 새로고침 버튼을 둔다. 새로 받는 동안은 같은
/// 자리에 로딩이 돈다. 덮는 색은 반투명 흰색이다 — 검은 칸이 회색으로 보여
/// "지난 것" 으로 읽히고, 대비가 낮아져 검표기가 굳이 읽어 보는 일도 줄인다.
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
          // 값이 바뀌면 위젯도 새것으로 본다. `QrImageView` 는 그린 코드를
          // 안에 들고 있어서, 키가 같으면 같은 상태를 이어받아 새 값이
          // 반영되지 않을 수 있다. 테스트가 QR 이 바뀌었는지 보는 창구이기도
          // 하다 — 그릴 문자열은 이 위젯 밖에서 읽을 수 없다.
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

/// 발급에 실패했을 때 QR 자리에 들어가는 안내. 문구는 서버 것 그대로다.
///
/// 목록 화면의 실패 안내([AsyncBoundary])와 같은 꼴이지만 그 위젯을 쓰지
/// 않는다. 저쪽은 Future 하나의 성공·실패를 가르는 틀이고, 이 화면은 같은
/// 요청을 몇 번이고 다시 보내며 이전 결과를 계속 그려야 해서 틀이 맞지 않는다.
/// 버튼 문구만 같은 상수를 써서 두 화면의 말이 갈리지 않게 한다.
class _IssueError extends StatelessWidget {
  const _IssueError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

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
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: const Text(AsyncBoundary.retryLabel),
          ),
        ],
      ),
    );
  }
}
