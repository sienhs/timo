import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/server_errors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/async_boundary.dart';
import '../../../core/widgets/error_snack_bar.dart';
import '../../../routes/app_routes.dart';
import '../../mypage/data/my_page_api.dart';
import '../../mypage/state/my_page_api_scope.dart';
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
import '../widgets/seat_map_layout.dart';
import '../widgets/seat_legend.dart';
import '../widgets/venue_map.dart';

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

  /// 예매자 실명을 받아 오는 데만 쓴다. 이 화면이 그리는 값은 없다.
  late MyPageApi _myPageApi;
  late int _concertId;
  late BookingController _controller;
  late Future<ZoneSeats> _seats;
  late int _zoneId;
  List<Zone> _zones = [];

  /// 선점 요청이 나가 있는 동안 참. 두 번 눌러 두 번 잡히지 않도록 결제하기
  /// 버튼을 잠가 둔다.
  bool _holding = false;

  /// 공연 상세로 돌아가는 중. 배치도 요청이 겹쳐 두 번 닫지 않게 한다.
  bool _restarting = false;

  @override
  void initState() {
    super.initState();
    _api = BookingApiScope.of(context);
    _myPageApi = MyPageApiScope.of(context);
    _controller = BookingScope.read(context);
    _concertId = _controller.concertId;
    _zoneId = widget.zoneId;
    // 다른 구역을 보다 나왔다면 그때 고른 자리는 여기서 유효하지 않다.
    _controller.enterZone(_zoneId);
    _seats = _fetch();
    _loadZones();
  }

  @override
  void dispose() {
    // 자리를 잡아 둔 채 화면이 사라지는 경우다(결제 완료 후 홈으로 빠지는 등).
    // 컨텍스트가 없어 요청만 던진다. 실패해도 5분 뒤 서버가 알아서 푼다.
    final hold = _controller.hold;
    if (hold != null) {
      _api.cancelHold(concertId: _concertId, seatId: hold.seatId).ignore();
    }
    super.dispose();
  }

  /// 좌석 배치도를 받는다. 보안문자 통과 기록이 끝났으면(403) 예매를 처음부터
  /// 다시 하게 한다 — 보안문자는 예매에 들어갈 때 한 번만 묻고, 이 화면 안에서
  /// 다시 띄우지 않는다.
  Future<ZoneSeats> _fetch() async {
    try {
      return await _api.fetchSeats(concertId: _concertId, zoneId: _zoneId);
    } on ApiException catch (e) {
      if (e.exceptionName != BookingServerErrors.captchaRequired) rethrow;
      _restartBooking();
      // 화면이 곧 닫혀 이 결과를 기다리는 곳이 없다. 던지면 받는 곳 없는 오류로
      // 남으므로 끝나지 않는 Future 를 준다.
      return Completer<ZoneSeats>().future;
    }
  }

  /// 공연 상세로 돌아가 예매하기부터 다시 하게 한다. 잡아 둔 자리는 화면이
  /// 사라지며 [dispose] 가 푼다.
  void _restartBooking() {
    if (!mounted || _restarting) return;
    _restarting = true;
    // 안내는 앱 전체의 스낵바 자리에 뜨므로 화면을 닫아도 남는다.
    showInfoSnackBar(context, BookingStrings.captchaSessionExpired);
    Navigator.popUntil(
      context,
      (route) => route.isFirst || route.settings.name == AppRoutes.showDetail,
    );
  }

  Future<void> _loadZones() async {
    try {
      final zones = await _api.fetchZones(_concertId);
      if (mounted) setState(() => _zones = zones);
    } catch (_) {
      // 구역도를 못 받아도 좌석 선택은 되게 둔다.
    }
  }

  void _changeZone(Zone zone) {
    if (_holding || _controller.hold != null || zone.id == _zoneId) return;
    _controller.clearSelection();
    setState(() {
      _zoneId = zone.id;
      _seats = _fetch();
    });
  }

  void _adjacentZone(int offset) {
    final current = _zones.indexWhere((z) => z.id == _zoneId);
    final next = current + offset;
    if (current >= 0 && next >= 0 && next < _zones.length) {
      _changeZone(_zones[next]);
    }
  }

  Future<void> _showMap() async {
    if (_zones.isEmpty) {
      Navigator.pop(context);
      return;
    }
    final zone = await showModalBottomSheet<Zone>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('이동할 구역을 선택하세요'),
                const SizedBox(height: 12),
                VenueMap(
                  zones: _zones,
                  selectedZoneId: _zoneId,
                  onZoneTap: (zone) => Navigator.pop(context, zone),
                ),
                for (final zone in _zones)
                  ListTile(
                    leading: Icon(
                      Icons.circle,
                      color: zoneColor(zone.id),
                      size: 14,
                    ),
                    title: Text(zone.name),
                    trailing: Text(
                      zone.isSoldOut ? '매진' : '${zone.availableCount}석',
                    ),
                    selected: zone.id == _zoneId,
                    onTap: () => Navigator.pop(context, zone),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted && zone != null) _changeZone(zone);
  }

  /// 좌석을 다시 받아 온다. 남이 잡았다 푼 자리가 이때 보인다. 화살표로 쓰면
  /// 대입식의 값(Future)이 콜백 반환값이 되어 Flutter 가 setState 안의 비동기
  /// 작업으로 보고 막는다.
  void _refresh() {
    final next = _fetch();
    setState(() {
      _seats = next;
    });
  }

  void _onSeatTap(ZoneSeats zoneSeats, Seat seat) {
    // 회색 자리(예매완료·선점중)는 눌러도 아무 말도 하지 않는다. 초록 자리를
    // 잡으려는데 그 사이 남이 채 간 경우(409)만 [_onHoldFailed] 가 알린다.
    if (_holding) return;

    final controller = BookingScope.read(context);

    // 고른 자리를 다시 누르면 선택을 푼다. 새로고침 사이에 남이 가져가 회색이
    // 된 자리도 풀 수 있어야 하므로 고를 수 있는지보다 먼저 본다.
    if (controller.selectedSeat?.id == seat.id) {
      controller.clearSelection();
      return;
    }

    if (!seat.isSelectable) return;
    controller.selectSeat(_zoneOf(zoneSeats), seat);
  }

  /// 확인을 받고 서버에 자리를 잡은 뒤 결제 화면으로 보낸다. 탭한 순간이 아니라
  /// 여기서 잡는다 — 오탭이 잦아 탭마다 요청하면 남의 자리까지 풀렸다 잡혔다
  /// 한다. 예매자 실명은 선점과 나란히 받아 결제 진입이 늦어지지 않게 한다.
  Future<void> _onCheckout() async {
    final seat = _controller.selectedSeat;
    final seatLabel = _controller.selectedSeatLabel;
    if (seat == null || seatLabel == null || _holding) return;

    final confirmed = await showSeatConfirmDialog(context, seatLabel);
    if (!confirmed || !mounted) return;

    final bookerName = _fetchBookerName();

    setState(() => _holding = true);
    try {
      final hold = await _api.holdSeat(concertId: _concertId, seatId: seat.id);
      if (!mounted) return;
      final name = await bookerName;
      if (!mounted) return;
      if (name != null) _controller.setBookerName(name);
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
      // 서버가 선점을 주문으로 바꿨으니 풀면 안 된다. 고른 자리를 잊고 배치도를
      // 새로 받아, 완료 화면에서 뒤로 돌아오면 판매 완료로 보이게 한다.
      _controller.clearSelection();
      _refresh();
      return;
    }

    // 결제를 마치지 않고 돌아왔다. 잡아 둔 자리를 놓아 남이 살 수 있게 한다.
    await _releaseHold();
  }

  /// 결제 화면에 찍을 예매자 실명. 실패하면 null 이고 던지지 않는다 — 선점과
  /// 나란히 떠 있다가 나중에 기다려지므로 예외로 끝나면 받는 곳이 없다. 형 변환
  /// 오류까지 받아 내야 결제가 멈추지 않아 [ApiException] 으로 좁히지 않는다.
  Future<String?> _fetchBookerName() async {
    try {
      return await _myPageApi.fetchBookerName();
    } catch (_) {
      return null;
    }
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

  /// 자리를 잡지 못했다. 서버는 자리를 뺏긴 것, 이 공연 티켓을 이미 가진 것,
  /// 판매 중이 아닌 공연을 전부 409 로 주므로 한 덩어리로 보면 안 된다 — 뒤의
  /// 둘은 자리와 무관해 한 문구로 뭉치면 전 좌석이 선점중인 것처럼 보인다.
  void _onHoldFailed(ApiException e) {
    if (e.status == 401) {
      // 로그인 화면은 성공하면 홈으로 가며 예매 화면을 걷어내므로, 공연 상세에서
      // 예매를 다시 시작한다. 세션이 도중에 끊긴 경우에만 여기 온다.
      _showMessage(BookingStrings.loginRequired);
      Navigator.pushNamed(context, AppRoutes.login);
      return;
    }

    // 자리 자체가 막힌 게 아니라면 고른 자리를 풀지도, 배치도를 다시 받지도
    // 않는다. 선택이 저절로 풀리면 사용자가 같은 일을 반복하게 된다.
    switch (e.exceptionName) {
      case BookingServerErrors.alreadyReserved:
        _showMessage(BookingStrings.alreadyReserved);
        return;
      case BookingServerErrors.concertNotOnSale:
        _showMessage(BookingStrings.concertNotOnSale);
        return;
    }

    if (e.status != 409) {
      _showMessage(e.message);
      return;
    }

    // 고르는 사이에 남이 가져갔다. 배치도가 낡았으므로 다시 받는다. 예외 이름이
    // 없거나 모르는 409 도 자리 경쟁으로 본다 — 가장 흔하고 새로고침은 해가 없다.
    _showMessage(BookingStrings.seatTaken);
    _controller.clearSelection();
    _refresh();
  }

  /// 좌석 응답이 함께 준 구역 정보로 [Zone] 을 만든다. 결제 금액과 좌석 이름에
  /// 필요한 건 그 둘뿐이라 구역 목록을 다시 받지 않는다.
  Zone _zoneOf(ZoneSeats zoneSeats) => Zone(
    id: zoneSeats.zoneId,
    name: zoneSeats.zoneName,
    price: zoneSeats.price,
    seatCount: zoneSeats.seatCount,
    availableCount: zoneSeats.availableCount,
    rowCount: zoneSeats.rows.length,
    seatsPerRow: zoneSeats.rows.isEmpty ? 0 : zoneSeats.rows.first.length,
  );

  /// 예매를 이어갈 수 없는 이유를 알린다. 하단 바는 `Scaffold.bottomNavigationBar`
  /// 라 Flutter 가 그 위로 올려 주므로 바 높이를 더하지 않는다.
  void _showMessage(String message) {
    showErrorSnackBar(context, message, bottomMargin: snackBarGapAboveBar);
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
          SeatLegend(zoneColor: zoneColor(_zoneId)),
          Expanded(
            child: AsyncBoundary<ZoneSeats>(
              key: ValueKey(_zoneId),
              future: _seats,
              onRetry: _refresh,
              builder: (context, zoneSeats) => Column(
                children: [
                  GestureDetector(
                    key: const ValueKey('zone-navigation'),
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragEnd: (details) {
                      if ((details.primaryVelocity ?? 0).abs() > 100) {
                        _adjacentZone(details.primaryVelocity! < 0 ? 1 : -1);
                      }
                    },
                    child: _ViewingZoneRow(
                      zoneName: zoneSeats.zoneName,
                      onChangeZone: _showMap,
                      minimap: _zones.isEmpty
                          ? null
                          : Semantics(
                              button: true,
                              excludeSemantics: true,
                              label: '전체 배치도에서 구역 변경',
                              onTap: _showMap,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _showMap,
                                child: IgnorePointer(
                                  child: VenueMap(
                                    zones: _zones,
                                    selectedZoneId: _zoneId,
                                    compact: true,
                                    onZoneTap: (_) {},
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      // 무대는 배치도 안쪽 맨 위에 그린다. 따로 띠를 두르면
                      // 부채꼴이 가리키는 무대와 띠가 두 개로 보인다.
                      child: SeatGrid(
                        key: ValueKey(_zoneId),
                        zoneColor: zoneColor(_zoneId),
                        // 구역도에서 이 구역이 어느 자리인지에 따라 무대가 붙는
                        // 방향과 좁아지는 방향이 달라진다.
                        surroundings: ZoneSurroundings.of(_zones, _zoneId),
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
                    Flexible(
                      child: Text(
                        '두 손가락으로 확대·이동 · 구역 이름을 밀어 구역 변경',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
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
  const _ViewingZoneRow({
    required this.zoneName,
    required this.onChangeZone,
    this.minimap,
  });
  final Widget? minimap;

  final String zoneName;
  final VoidCallback onChangeZone;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          if (minimap != null) ...[
            SizedBox(width: 48, height: 44, child: minimap),
            const SizedBox(width: 8),
          ],
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
              maxLines: 2,
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
