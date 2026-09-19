import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/async_boundary.dart';
import '../../../routes/app_routes.dart';
import '../constants.dart';
import '../data/booking_api.dart';
import '../models/zone.dart';
import '../state/booking_api_scope.dart';
import '../state/booking_scope.dart';
import '../widgets/performance_header.dart';
import '../widgets/venue_map.dart';
import '../widgets/zone_info_panels.dart';

/// 시안 '좌석 선택 시작' 화면. 구역 배치도에서 구역을 골라 들어간다.
class ZoneSelectionScreen extends StatefulWidget {
  const ZoneSelectionScreen({super.key, required this.concertId});

  /// 서버가 준 공연 번호. 구역과 잔여석은 공연마다 다르다.
  final int concertId;

  @override
  State<ZoneSelectionScreen> createState() => _ZoneSelectionScreenState();
}

/// 두 패널은 동시에 열리지 않는다(시안에서도 한 번에 하나만 펼쳐진다).
/// bool 두 개로 두면 '둘 다 열림'이라는 없는 상태가 표현되므로 enum 으로 둔다.
enum _OpenPanel { none, remainingSeats, price }

class _ZoneSelectionScreenState extends State<ZoneSelectionScreen> {
  _OpenPanel _open = _OpenPanel.none;

  late BookingApi _api;
  late Future<List<Zone>> _zones;

  @override
  void initState() {
    super.initState();
    // 이 화면이 예매 흐름의 시작이다. 어느 공연인지 여기서 정해 두면 좌석·결제
    // 화면이 라우트 인자를 다시 나르지 않아도 된다.
    BookingScope.read(context).startBooking(widget.concertId);
    _api = BookingApiScope.of(context);
    _zones = _api.fetchZones(widget.concertId);
  }

  void _toggle(_OpenPanel panel) {
    setState(() => _open = _open == panel ? _OpenPanel.none : panel);
  }

  void _openZone(Zone zone) {
    if (zone.isSoldOut) {
      // '구역은' 으로 붙이는 이유: 구역명이 'FLOOR B'(비) 처럼 모음으로 끝나면
      // '은' 이 틀린다. 이름마다 조사를 고를 수 없으니 조사가 필요 없는 형태로 쓴다.
      _showMessage(BookingStrings.zoneSoldOut(zone.name));
      return;
    }
    Navigator.pushNamed(context, AppRoutes.seatSelection, arguments: zone.id);
  }

  /// 구역 목록을 다시 받아 온다.
  ///
  /// 취소된 좌석은 3분 1초~15분 사이 랜덤한 시각에 다시 열린다(S15P21D206-347).
  /// 풀리는 순간을 겨냥할 수 없으니 "취소표를 겨냥한 자동 새로고침이 겨냥할
  /// 시점을 갖지 못하게 한다"는 요구사항과 이 버튼은 어긋나지 않는다.
  /// 화살표로 쓰지 않는 이유는 좌석 화면의 같은 메서드 주석 참고.
  void _refresh() {
    final next = _api.fetchZones(widget.concertId);
    setState(() {
      _zones = next;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final controller = BookingScope.of(context);

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
          _DisclosureRow(open: _open, onToggle: _toggle),
          Expanded(
            child: AsyncBoundary<List<Zone>>(
              future: _zones,
              onRetry: _refresh,
              builder: (context, zones) => switch (_open) {
                _OpenPanel.none => _MapSection(
                  zones: zones,
                  onZoneTap: _openZone,
                ),
                _OpenPanel.remainingSeats => RemainingSeatsPanel(
                  zones: zones,
                  onZoneTap: _openZone,
                ),
                _OpenPanel.price => ZonePricePanel(zones: zones),
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// '잔여좌석보기' · '좌석가격보기' 토글 두 개.
class _DisclosureRow extends StatelessWidget {
  const _DisclosureRow({required this.open, required this.onToggle});

  final _OpenPanel open;
  final void Function(_OpenPanel panel) onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _DisclosureButton(
              label: '잔여좌석보기',
              expanded: open == _OpenPanel.remainingSeats,
              onTap: () => onToggle(_OpenPanel.remainingSeats),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _DisclosureButton(
              label: '좌석가격보기',
              expanded: open == _OpenPanel.price,
              onTap: () => onToggle(_OpenPanel.price),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisclosureButton extends StatelessWidget {
  const _DisclosureButton({
    required this.label,
    required this.expanded,
    required this.onTap,
  });

  final String label;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _MapSection extends StatelessWidget {
  const _MapSection({required this.zones, required this.onZoneTap});

  final List<Zone> zones;
  final void Function(Zone zone) onZoneTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.touch_app_outlined,
                size: 15,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text('구역을 눌러 확대할 수 있어요', style: textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: 12),
          VenueMap(zones: zones, onZoneTap: onZoneTap),
          const SizedBox(height: 10),
          Text(
            '* 1인 1매만 예매할 수 있어요',
            textAlign: TextAlign.center,
            style: textTheme.labelSmall?.copyWith(color: AppColors.accent),
          ),
        ],
      ),
    );
  }
}
