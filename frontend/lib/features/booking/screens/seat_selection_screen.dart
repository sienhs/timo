import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/async_boundary.dart';
import '../../../routes/app_routes.dart';
import '../constants.dart';
import '../data/booking_api.dart';
import '../models/seat.dart';
import '../models/zone.dart';
import '../models/zone_seats.dart';
import '../state/booking_api_scope.dart';
import '../state/booking_controller.dart';
import '../state/booking_scope.dart';
import '../widgets/booking_bottom_bar.dart';
import '../widgets/performance_header.dart';
import '../widgets/seat_confirm_dialog.dart';
import '../widgets/seat_grid.dart';
import '../widgets/seat_legend.dart';

/// 시안 '좌석 상세 선택' 화면. 구역 하나의 좌석 배치도에서 한 석을 고른다.
class SeatSelectionScreen extends StatefulWidget {
  const SeatSelectionScreen({super.key, required this.zoneId});

  /// 서버가 준 구역 번호. 공연 번호는 예매 상태([BookingScope])가 들고 있다.
  final int zoneId;

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  late BookingApi _api;
  late int _concertId;
  late BookingController _controller;
  late Future<ZoneSeats> _seats;

  /// 선점 요청이 나가 있는 동안 참. 결제하기 버튼을 잠가 둔다.
  ///
  /// 두 번 눌러 두 번 잡히는 것을 막는 것이 첫째지만, 요청이 오가는 몇 백
  /// 밀리초 동안 버튼이 멀쩡해 보이면 사용자는 눌리지 않았다고 생각한다.
  bool _holding = false;

  @override
  void initState() {
    super.initState();
    _api = BookingApiScope.of(context);
    _controller = BookingScope.read(context);
    _concertId = _controller.concertId;
    _seats = _fetch();
  }

  @override
  void dispose() {
    // 자리를 잡아 둔 채 화면이 사라지는 경우다(결제 완료 후 홈으로 빠지는 등).
    // 컨텍스트가 이미 없어 결과를 볼 수 없으므로 요청만 던진다. 실패해도
    // 5분 뒤 서버가 알아서 푼다.
    final hold = _controller.hold;
    if (hold != null) {
      _api.cancelHold(concertId: _concertId, seatId: hold.seatId).ignore();
    }
    super.dispose();
  }

  Future<ZoneSeats> _fetch() =>
      _api.fetchSeats(concertId: _concertId, zoneId: widget.zoneId);

  /// 좌석을 다시 받아 온다. 남이 잡았다 푼 자리가 이때 보인다.
  ///
  /// 화살표로 쓰지 않는다. `setState(() => _seats = _fetch())` 는 대입식의
  /// 값(Future)을 콜백의 반환값으로 넘기게 되어, Flutter 가 "setState 안에서
  /// 비동기 작업을 한다" 고 보고 막는다.
  void _refresh() {
    final next = _fetch();
    setState(() {
      _seats = next;
    });
  }

  void _onSeatTap(ZoneSeats zoneSeats, Seat seat) {
    // 회색 자리(예매완료·선점중)는 눌러도 아무 말도 하지 않는다. 고를 수 없다는
    // 것이 색으로 이미 보이고, 배치도를 훑다 보면 회색을 스치듯 누르는 일이
    // 잦아서 그때마다 안내를 띄우면 스낵바가 떴다 사라지기를 반복한다.
    //
    // 알려 줘야 하는 경우는 따로 있다. 초록 자리를 눌러 잡으려는데 그 사이
    // 남이 채 간 때다(409). 그건 [_onHoldFailed] 가 맡는다.
    if (!seat.isSelectable) return;
    BookingScope.read(context).selectSeat(_zoneOf(zoneSeats), seat);
  }

  /// 확인을 받고 서버에 자리를 잡은 뒤 결제 화면으로 보낸다.
  ///
  /// **탭한 순간이 아니라 여기서 잡는다.** 칸이 작아 오탭이 잦은데 탭마다
  /// 요청을 보내면 남의 자리까지 풀렸다 잡혔다 한다.
  Future<void> _onCheckout() async {
    final seat = _controller.selectedSeat;
    final seatLabel = _controller.selectedSeatLabel;
    if (seat == null || seatLabel == null || _holding) return;

    final confirmed = await showSeatConfirmDialog(context, seatLabel);
    if (!confirmed || !mounted) return;

    setState(() => _holding = true);
    try {
      final hold = await _api.holdSeat(concertId: _concertId, seatId: seat.id);
      if (!mounted) return;
      _controller.holdSeat(hold);
    } on ApiException catch (e) {
      if (mounted) _onHoldFailed(e);
      return;
    } finally {
      if (mounted) setState(() => _holding = false);
    }

    // 결제 화면은 주문을 만들었으면 true 를 남기고 완료 화면으로 교체된다.
    // 그 순간 이 대기가 풀린다 — 완료 화면이 닫힐 때가 아니다.
    final paid = await Navigator.pushNamed(context, AppRoutes.payment);
    if (!mounted) return;

    if (paid == true) {
      // 서버가 선점을 주문으로 바꿨다. 여기서 풀면 안 된다 — 이미 우리
      // 자리다. 고른 자리를 잊고 배치도를 새로 받아, 완료 화면에서 뒤로
      // 돌아오면 그 자리가 판매 완료로 보이게 한다.
      _controller.clearSelection();
      _refresh();
      return;
    }

    // 결제를 마치지 않고 돌아왔다. 잡아 둔 자리를 놓아 남이 살 수 있게 한다.
    await _releaseHold();
  }

  /// 잡아 둔 자리를 푼다. 실패는 삼킨다 — 5분 뒤 서버가 알아서 푼다.
  Future<void> _releaseHold() async {
    final hold = _controller.hold;
    if (hold == null) return;

    _controller.clearHold();
    try {
      await _api.cancelHold(concertId: _concertId, seatId: hold.seatId);
    } on ApiException {
      return;
    }
    // 놓은 자리가 다시 예매 가능으로 보이도록 배치도를 새로 받는다.
    if (mounted) _refresh();
  }

  void _onHoldFailed(ApiException e) {
    switch (e.status) {
      case 401:
        // 서버가 요청자를 알아야 자리를 잡아 준다. 로그인 화면은 성공하면
        // 홈으로 가며 예매 화면을 걷어내므로, 공연 상세에서 예매를 다시 시작한다.
        // 상세에서 로그인을 먼저 확인하기 때문에 여기 오는 일은 세션이 도중에
        // 끊긴 경우뿐이다.
        _showMessage(BookingStrings.loginRequired);
        Navigator.pushNamed(context, AppRoutes.login);
      case 409:
        // 고르는 사이에 남이 가져갔다. 지금 배치도는 이미 낡았으므로 다시 받는다.
        _showMessage(BookingStrings.seatTaken);
        _controller.clearSelection();
        _refresh();
      default:
        _showMessage(e.message);
    }
  }

  /// 좌석 응답이 함께 준 구역 정보로 [Zone] 을 만든다.
  ///
  /// 구역 목록을 다시 받지 않는 이유: 서버가 좌석 응답 머리에 구역 이름과
  /// 가격을 실어 준다. 결제 금액과 좌석 이름에 필요한 건 그 둘뿐이다.
  Zone _zoneOf(ZoneSeats zoneSeats) => Zone(
    id: zoneSeats.zoneId,
    name: zoneSeats.zoneName,
    price: zoneSeats.price,
    seatCount: zoneSeats.seatCount,
    availableCount: zoneSeats.availableCount,
    rowCount: zoneSeats.rows.length,
    seatsPerRow: zoneSeats.rows.isEmpty ? 0 : zoneSeats.rows.first.length,
  );

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final controller = BookingScope.of(context);
    final selectedSeat = controller.selectedSeat;

    return Scaffold(
      appBar: AppBar(
        title: const Text('좌석 선택'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: '좌석 정보 새로고침',
          ),
        ],
      ),
      body: Column(
        children: [
          PerformanceHeader(performance: controller.performance),
          const SeatLegend(),
          Expanded(
            child: AsyncBoundary<ZoneSeats>(
              future: _seats,
              onRetry: _refresh,
              builder: (context, zoneSeats) => Column(
                children: [
                  _ViewingZoneRow(
                    zoneName: zoneSeats.zoneName,
                    onChangeZone: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SeatGrid(
                        seatsPerRow: _zoneOf(zoneSeats).seatsPerRow,
                        seatRows: zoneSeats.rows,
                        selectedSeatId: selectedSeat?.id,
                        onSeatTap: (seat) => _onSeatTap(zoneSeats, seat),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Column(
              children: [
                // 좌석이 화면 폭을 넘으므로 확대·이동이 가능하다는 걸 알려준다.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.zoom_out_map,
                      size: 13,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '두 손가락으로 확대·이동할 수 있어요',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '* 1인 1매만 예매할 수 있어요',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: AppColors.accent),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BookingBottomBar(
        seatLabel: controller.selectedSeatLabel,
        amount: controller.payableAmount,
        actionLabel: '결제하기',
        // 자리를 잡는 동안에도 잠근다. 두 번 누르면 두 번 잡힌다.
        onPressed: selectedSeat == null || _holding ? null : _onCheckout,
      ),
    );
  }
}

/// '지금 보고 있는 구역은 ... 입니다' + 구역 변경 버튼.
class _ViewingZoneRow extends StatelessWidget {
  const _ViewingZoneRow({required this.zoneName, required this.onChangeZone});

  final String zoneName;
  final VoidCallback onChangeZone;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: '지금 보고 있는 구역은 '),
                  TextSpan(
                    text: zoneName,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  // 구역명이 서버에서 오므로 받침을 알 수 없다. '이에요'/'예요'
                  // 를 고를 수 없어 조사가 필요 없는 형태로 끊는다.
                  const TextSpan(text: ' 입니다'),
                ],
              ),
              style: textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onChangeZone,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: const BorderRadius.all(Radius.circular(4)),
              ),
              child: Text('구역 변경', style: textTheme.labelMedium),
            ),
          ),
        ],
      ),
    );
  }
}
