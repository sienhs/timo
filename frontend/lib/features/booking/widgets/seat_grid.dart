import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/seat.dart';
import '../models/zone.dart';
import 'seat_colors.dart';

/// 좌석 한 칸의 한 변. 권장 터치 타겟(44pt) 기준이다.
const _cellSize = 44.0;

/// 셀 간격. 셀 + 간격 = 48px 로, Material 최소 터치 타겟(48dp) 피치가 된다.
const _cellGap = 4.0;

const _rowHeight = _cellSize + _cellGap;

/// 열 라벨('15열') 폭. 구역명은 그리드 위에 이미 적혀 있으므로 열 번호만 둔다.
const _labelWidth = 38.0;

/// 캔버스 안쪽 여백. 없으면 열 라벨이 프레임 테두리에 붙는다.
const _canvasPadding = EdgeInsets.fromLTRB(12, 8, 12, 8);

/// 구역 하나의 좌석 배치도.
///
/// 셀을 권장 터치 타겟(44px)으로 두면 한 구역(18~22석 x 8~15열)이 폰 화면에
/// 들어가지 않는다. 그래서 [InteractiveViewer] 로 확대·이동하게 했다.
/// 시안의 "구역을 눌러 확대할 수 있어요" 안내도 이 동작을 가리킨다.
///
/// 기본 배율은 1.0 이다. 처음부터 정확히 누를 수 있는 크기로 보여주고,
/// 전체 구역을 훑어보고 싶으면 두 손가락으로 축소한다.
///
/// 더블탭으로 전체 보기를 왕복하는 방식도 만들어 봤지만, 조상에 붙인
/// onDoubleTap 이 제스처 아레나에서 좌석의 단일 탭을 붙잡아 선택이 한 박자
/// 늦어졌다. 확대는 핀치만으로 충분하므로 더블탭은 두지 않는다.
///
/// 셀 안에 좌석 번호는 넣지 않는다. 시안대로 색만 칠한 사각형이며, 고른 자리가
/// 몇 번인지는 결제 직전 확인 다이얼로그가 알려준다. 44px 는 번호를 넣기 위한
/// 크기가 아니라 터치 타겟 기준이므로, 번호가 없어도 줄이지 않는다.
class SeatGrid extends StatefulWidget {
  const SeatGrid({
    super.key,
    required this.zone,
    required this.seatRows,
    required this.selectedSeatId,
    required this.onSeatTap,
  });

  final Zone zone;
  final List<List<Seat>> seatRows;

  /// 선택된 좌석 id 만 내려받는다. 좌석 칸마다 컨트롤러를 구독하면
  /// InheritedWidget 의존 위젯이 수백 개가 되어 알림 비용이 커진다.
  final String? selectedSeatId;

  final void Function(Seat seat) onSeatTap;

  @override
  State<SeatGrid> createState() => _SeatGridState();
}

class _SeatGridState extends State<SeatGrid> {
  /// 열 라벨을 고정하려면 변환 행렬을 직접 읽어야 한다.
  final _transform = TransformationController();

  /// 전체 구역이 화면에 들어가는 최소 배율.
  static const _minScale = 0.42;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zone = widget.zone;
    final canvasWidth = _canvasPadding.horizontal +
        _labelWidth +
        zone.seatsPerRow * (_cellSize + _cellGap);

    // 프레임으로 감싸는 이유: 44px 셀이면 18석이 폰 폭에 절대 안 들어가고,
    // 화면 끝에서 셀이 반쯤 잘린다. 테두리 없이 두면 스크롤 가능한 영역이
    // 아니라 레이아웃이 깨진 것처럼 읽힌다. 테두리 안에서 잘리면 '창 안을
    // 들여다보는' 것으로 보인다.
    return DecoratedBox(
      // 테두리를 자식 위에 그린다. 기본값(background)으로 두면 고정 열 라벨의
      // 불투명 배경이 왼쪽 위 테두리를 덮어 선이 끊겨 보인다.
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: Stack(
          children: [
            InteractiveViewer(
              transformationController: _transform,
              // 캔버스가 화면보다 크므로 자연 크기를 그대로 쓰게 한다.
              constrained: false,
              minScale: _minScale,
              maxScale: 2,
              // 끝까지 밀었을 때 셀이 테두리에 붙지 않게 여백을 준다.
              boundaryMargin: const EdgeInsets.all(10),
              child: SizedBox(
                width: canvasWidth,
                // 좌석 칸이 수백 개라 선택이 바뀔 때의 재페인트를 이 안에 가둔다.
                child: RepaintBoundary(
                  child: Padding(
                    padding: _canvasPadding,
                    child: Column(
                      children: [
                        for (final row in widget.seatRows)
                          _SeatRow(
                            row: row,
                            selectedSeatId: widget.selectedSeatId,
                            onSeatTap: widget.onSeatTap,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // 열 라벨은 가로로 밀어도 남아야 한다. 셀에 아무 글자도 없어서
            // 라벨이 사라지면 어디를 보고 있는지 알 수 있는 단서가 없다.
            // 캔버스 밖에 두고 세로 이동·배율만 따라간다.
            //
            // Positioned 로 감싸는 이유: Stack 의 일반 자식은 Stack 높이로
            // 제약되어 열이 많으면 Column 이 넘친다. top/left 만 준 Positioned
            // 는 제약이 무제한이라 자연 높이로 그려지고, 넘는 부분은
            // ClipRRect 가 자른다.
            Positioned(
              top: 0,
              left: 0,
              child: _PinnedRowLabels(
                transform: _transform,
                rowNumbers: [for (final row in widget.seatRows) row.first.row],
              ),
            ),
            // 오른쪽·아래에 옅은 페이드를 깔아 '더 있다'를 알린다.
            // IgnorePointer 로 좌석 탭을 가로막지 않게 한다.
            const IgnorePointer(
              child: Align(
                alignment: Alignment.centerRight,
                child: _EdgeFade(Axis.horizontal),
              ),
            ),
            const IgnorePointer(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _EdgeFade(Axis.vertical),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 가로 이동과 무관하게 왼쪽에 붙어 있는 열 라벨.
///
/// [InteractiveViewer] 의 변환에서 **세로 이동과 배율만** 뽑아 적용한다.
/// 그래서 위아래로 밀면 좌석과 같이 움직이고, 좌우로 밀면 제자리에 남는다.
class _PinnedRowLabels extends StatelessWidget {
  const _PinnedRowLabels({required this.transform, required this.rowNumbers});

  final TransformationController transform;
  final List<int> rowNumbers;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelMedium;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: transform,
        builder: (context, _) {
          final matrix = transform.value;
          final scale = matrix.getMaxScaleOnAxis();
          final dy = matrix.getTranslation().y;

          return Transform(
            // InteractiveViewer 와 같은 순서(이동 후 배율)로 조립해야 좌석과
            // 세로 위치가 어긋나지 않는다.
            transform: Matrix4.identity()
              ..translateByDouble(0, dy, 0, 1)
              ..scaleByDouble(scale, scale, 1, 1),
            child: Container(
              width: _canvasPadding.left + _labelWidth,
              // 좌석이 이 아래로 지나가므로 불투명해야 한다.
              color: AppColors.surface,
              padding: EdgeInsets.only(
                top: _canvasPadding.top,
                left: _canvasPadding.left,
              ),
              child: Column(
                children: [
                  for (final number in rowNumbers)
                    SizedBox(
                      height: _rowHeight,
                      width: _labelWidth,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('$number열', style: labelStyle, maxLines: 1),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SeatRow extends StatelessWidget {
  const _SeatRow({
    required this.row,
    required this.selectedSeatId,
    required this.onSeatTap,
  });

  final List<Seat> row;
  final String? selectedSeatId;
  final void Function(Seat seat) onSeatTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _rowHeight,
      child: Row(
        children: [
          // 라벨 자리를 비워둔다. 글자는 [_PinnedRowLabels] 가 그린다.
          const SizedBox(width: _labelWidth),
          for (final seat in row)
            Padding(
              padding: const EdgeInsets.only(right: _cellGap),
              child: _SeatCell(
                // 'A-9-6'. 좌석을 지목해 탭하는 테스트에 쓴다.
                key: ValueKey(seat.id),
                seat: seat,
                state: seatCellStateOf(seat, selectedSeatId),
                onTap: onSeatTap,
              ),
            ),
        ],
      ),
    );
  }
}

class _SeatCell extends StatelessWidget {
  const _SeatCell({
    super.key,
    required this.seat,
    required this.state,
    required this.onTap,
  });

  final Seat seat;
  final SeatCellState state;
  final void Function(Seat seat) onTap;

  @override
  Widget build(BuildContext context) {
    final colors = seatCellColors(state);

    // 예매 완료 좌석도 탭은 받는다. 아무 일도 일어나지 않으면 사용자는
    // 왜 안 되는지 알 수 없다. 사유 안내는 화면(onTap)이 맡는다.
    return GestureDetector(
      onTap: () => onTap(seat),
      behavior: HitTestBehavior.opaque,
      child: SizedBox.square(
        dimension: _cellSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.fill,
            border: Border.all(color: colors.border),
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
        ),
      ),
    );
  }
}

/// 잘린 가장자리에 깔리는 옅은 그라데이션. 내용이 더 있다는 신호다.
class _EdgeFade extends StatelessWidget {
  const _EdgeFade(this.axis);

  final Axis axis;

  static const _thickness = 22.0;

  @override
  Widget build(BuildContext context) {
    final horizontal = axis == Axis.horizontal;

    return SizedBox(
      width: horizontal ? _thickness : double.infinity,
      height: horizontal ? double.infinity : _thickness,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: horizontal ? Alignment.centerRight : Alignment.bottomCenter,
            end: horizontal ? Alignment.centerLeft : Alignment.topCenter,
            colors: [
              AppColors.surface,
              AppColors.surface.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
