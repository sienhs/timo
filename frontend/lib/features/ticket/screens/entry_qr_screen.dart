import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/poster_image.dart';
import '../constants.dart';
import '../models/entry_pass.dart';
import '../models/my_ticket.dart';
import '../widgets/qr_countdown_bar.dart';
import '../widgets/qr_notice_box.dart';

/// 입장 QR. 예정 공연 카드의 '입장 QR 보기' 로 들어온다.
///
/// QR 은 30초마다 새로 만들어진다. 만드는 일 자체는 [EntryPass] 가 알고, 이
/// 화면은 **언제** 다시 만들지와 남은 시간만 센다.
///
/// 초마다 다시 그리는 것은 카운트다운과 진행 바뿐이고, QR 은 30초에 한 번만
/// 바뀐다. 그래서 [EntryPass] 를 매초 새로 만들지 않고 남은 시간만 다시 잰다 —
/// 매초 새 QR 을 만들면 화면이 깜빡이고 검표기가 읽는 도중에 값이 바뀐다.
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
  /// QR 을 "25초 남음" 으로 보여주게 된다.
  ///
  /// 그래서 시계를 밖에서 받을 수 있게 열어 둔다. 테스트가 시간을 돌리는 창구다.
  final DateTime Function()? clock;

  @override
  State<EntryQrScreen> createState() => _EntryQrScreenState();
}

class _EntryQrScreenState extends State<EntryQrScreen> {
  late EntryPass _pass;
  late Duration _remaining;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _issue();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  DateTime get _now => (widget.clock ?? DateTime.now)();

  void _issue() {
    _pass = EntryPass.issue(
      reservationId: widget.ticket.reservationId,
      now: _now,
    );
    _remaining = EntryPass.lifetime;
  }

  void _tick() {
    final now = _now;
    final remaining = _pass.remaining(now);
    setState(() {
      if (remaining == Duration.zero) {
        _issue();
      } else {
        _remaining = remaining;
      }
    });
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
            _QrPanel(pass: _pass, remaining: _remaining),
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
class _QrPanel extends StatelessWidget {
  const _QrPanel({required this.pass, required this.remaining});

  final EntryPass pass;
  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
            child: QrImageView(
              // 값이 바뀌면 위젯도 새것으로 본다. `QrImageView` 는 그린 코드를
              // 안에 들고 있어서, 키가 같으면 같은 상태를 이어받아 새 값이
              // 반영되지 않을 수 있다. 테스트가 QR 이 바뀌었는지 보는 창구이기도
              // 하다 — 그릴 문자열은 이 위젯 밖에서 읽을 수 없다.
              key: ValueKey(pass.payload),
              data: pass.payload,
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
          ),
          const SizedBox(height: 20),
          QrCountdownBar(
            remaining: remaining,
            progress:
                remaining.inMilliseconds / EntryPass.lifetime.inMilliseconds,
          ),
          const SizedBox(height: 12),
          Text(
            TicketStrings.qrRotateNotice,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
