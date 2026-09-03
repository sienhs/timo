import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../routes/app_routes.dart';
import '../models/seat.dart';
import '../models/zone.dart';
import '../state/booking_scope.dart';
import '../widgets/booking_bottom_bar.dart';
import '../widgets/performance_header.dart';
import '../widgets/seat_confirm_dialog.dart';
import '../widgets/seat_grid.dart';
import '../widgets/seat_legend.dart';

/// 시안 '좌석 상세 선택' 화면. 구역 하나의 좌석 배치도에서 한 석을 고른다.
class SeatSelectionScreen extends StatefulWidget {
  const SeatSelectionScreen({super.key, required this.zoneId});

  final String zoneId;

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  void _onSeatTap(Seat seat) {
    // 고를 수 없는 좌석도 탭을 받아 사유를 알려준다. 셀이 10px 대라 오탭이
    // 잦은데 아무 반응이 없으면 사용자는 앱이 멈춘 줄로 안다.
    switch (seat.status) {
      case SeatStatus.sold:
        _showMessage('이미 예매가 완료된 좌석이에요.');
        return;
      case SeatStatus.available:
        BookingScope.read(context).selectSeat(seat);
        return;
    }
  }

  Future<void> _onCheckout() async {
    final controller = BookingScope.read(context);
    final seat = controller.selectedSeat;
    if (seat == null) return;

    final confirmed = await showSeatConfirmDialog(context, seat);
    if (!confirmed || !mounted) return;

    await Navigator.pushNamed(context, AppRoutes.payment);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final controller = BookingScope.of(context);
    final zone = controller.zoneById(widget.zoneId);
    final selectedSeat = controller.selectedSeat;

    return Scaffold(
      appBar: AppBar(
        title: const Text('좌석 선택'),
        actions: [
          IconButton(
            onPressed: () => _showMessage('좌석 정보를 새로 불러왔어요.'),
            icon: const Icon(Icons.refresh),
            tooltip: '좌석 정보 새로고침',
          ),
        ],
      ),
      body: Column(
        children: [
          PerformanceHeader(performance: controller.performance),
          const SeatLegend(),
          _ViewingZoneRow(
            zone: zone,
            onChangeZone: () => Navigator.pop(context),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SeatGrid(
                zone: zone,
                seatRows: controller.seatRowsOf(zone.id),
                selectedSeatId: selectedSeat?.id,
                onSeatTap: _onSeatTap,
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
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: AppColors.accent),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BookingBottomBar(
        seatLabel: selectedSeat?.label,
        amount: controller.payableAmount,
        actionLabel: '결제하기',
        onPressed: selectedSeat == null ? null : _onCheckout,
      ),
    );
  }
}

/// '지금 보고 있는 구역은 A구역이에요' + 구역 변경 버튼.
class _ViewingZoneRow extends StatelessWidget {
  const _ViewingZoneRow({required this.zone, required this.onChangeZone});

  final Zone zone;
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
                    text: zone.shortLabel,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(text: '이에요'),
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
