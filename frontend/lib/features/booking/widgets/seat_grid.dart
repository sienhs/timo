import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/seat.dart';
import 'seat_colors.dart';
import 'seat_map_layout.dart';

/// 구역 하나의 좌석 배치도. 격자가 아니라 공연장 모양(무대·부채꼴·통로)으로
/// 그리되 자리 수와 번호는 서버가 준 그대로다. 셀은 터치 타겟 44px 라 한 구역이
/// 폰 화면에 안 들어가므로 [InteractiveViewer] 로 확대·이동하고, 처음에는 구역
/// 전체가 보이는 배율로 시작한다. 조상에 onDoubleTap 을 달면 좌석 탭이 늦어진다.
class SeatGrid extends StatefulWidget {
  const SeatGrid({
    super.key,
    required this.seatsPerRow,
    required this.seatRows,
    required this.selectedSeatId,
    required this.onSeatTap,
    this.zoneColor,
    this.surroundings = const ZoneSurroundings(),
  });
  final Color? zoneColor;

  /// 이 구역 둘레에 무엇이 있는지(무대·이웃 구역). 좁아지는 방향도 여기서 온다.
  final ZoneSurroundings surroundings;

  /// 한 열에 들어가는 칸 수. 캔버스 폭을 정한다. 자리 목록에서 세면 통로로
  /// 끝자리가 빈 줄마다 길이가 달라지므로 서버가 알려 준 격자 크기를 쓴다.
  final int seatsPerRow;

  /// 열 → 자리. 자리가 없는 칸(통로)은 null 이다.
  final List<List<Seat?>> seatRows;

  /// 선택된 좌석 id 만 내려받는다. 좌석 칸마다 컨트롤러를 구독하면
  /// InheritedWidget 의존 위젯이 수백 개가 되어 알림 비용이 커진다.
  final int? selectedSeatId;

  final void Function(Seat seat) onSeatTap;

  @override
  State<SeatGrid> createState() => _SeatGridState();
}

class _SeatGridState extends State<SeatGrid> {
  /// 열 라벨을 고정하려면 변환 행렬을 직접 읽어야 한다.
  final _transform = TransformationController();

  /// 처음 한 번만 배율을 맞췄는지. 그 뒤에는 사용자가 확대·이동한 자리를 존중한다.
  bool _fitted = false;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  /// 배치도 전체가 화면에 들어오는 배율. 축소 한계로 쓴다. 상수로 두면 구역이
  /// 조금만 커져도 다 보이지 않고, 작은 구역에서는 좌석이 점이 된다.
  double _fitScale(SeatMapLayout layout, BoxConstraints constraints) {
    if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) return 1;
    if (layout.canvasWidth <= 0 || layout.canvasHeight <= 0) return 1;

    final fit = math.min(
      constraints.maxWidth / layout.canvasWidth,
      constraints.maxHeight / layout.canvasHeight,
    );
    // 1.0 을 넘길 이유는 없다. 배치도가 화면보다 작으면 그냥 제 크기로 둔다.
    // 바닥을 두는 것은 0 이하가 되면 InteractiveViewer 가 단언에 걸리기 때문이다.
    return fit.clamp(0.05, 1.0);
  }

  /// 축소 한계까지 실제로 줄어들게 하는 경계 여백. [InteractiveViewer] 는 화면이
  /// 경계 밖으로 나가지 않는 선에서만 배율을 낮추므로, 여백이 좁으면 [minScale]
  /// 을 아무리 작게 줘도 안 줄어든다. 배율에 따라 여백을 바꾸면 그 배율이 곧 새
  /// 한계가 되어 역시 안 줄어든다.
  EdgeInsets _panBoundary(
    SeatMapLayout layout,
    BoxConstraints constraints,
    double minScale,
  ) {
    // 끝까지 밀었을 때 셀이 테두리에 붙지 않게 두는 최소 여백.
    const breathing = 10.0;
    if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
      return const EdgeInsets.all(breathing);
    }

    final horizontal =
        (constraints.maxWidth / minScale - layout.canvasWidth) / 2;
    final vertical =
        (constraints.maxHeight / minScale - layout.canvasHeight) / 2;

    return EdgeInsets.symmetric(
      horizontal: math.max(0, horizontal) + breathing,
      vertical: math.max(0, vertical) + breathing,
    );
  }

  /// 손을 뗀 뒤 배치도가 화면 밖으로 나가 있으면 도로 끌어온다. 축소 한계를
  /// 받치는 큰 경계 여백([_panBoundary])이 확대한 상태에서도 살아 있어, 경계로는
  /// 막을 수 없기 때문이다.
  void _clampPan(SeatMapLayout layout, BoxConstraints constraints) {
    if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) return;

    final matrix = _transform.value;
    final scale = matrix.getMaxScaleOnAxis();
    final translation = matrix.getTranslation();

    final dx = _clampAxis(
      translation.x,
      layout.canvasWidth * scale,
      constraints.maxWidth,
    );
    final dy = _clampAxis(
      translation.y,
      layout.canvasHeight * scale,
      constraints.maxHeight,
    );
    if (dx == translation.x && dy == translation.y) return;

    // 행렬을 새로 조립하지 않고 이동값만 바꾼다. 다시 조립하면 z 축 배율을
    // 빠뜨리기 쉽고, 그러면 열 라벨이 읽는 getMaxScaleOnAxis() 가 1 이 된다.
    _transform.value = Matrix4.copy(matrix)..setTranslationRaw(dx, dy, 0);
  }

  /// 한 축의 이동량을 '배치도가 화면에 남아 있는' 범위로 자른다.
  static double _clampAxis(double offset, double content, double viewport) {
    // 화면보다 작으면 가운데 놓는다. 끝까지 줄였을 때가 이 경우다.
    if (content <= viewport) return (viewport - content) / 2;

    // 가장자리에 숨 쉴 틈만 남기고 그 밖으로는 못 나가게 한다.
    const slack = 16.0;
    return offset.clamp(viewport - content - slack, slack);
  }

  /// 처음에는 구역 전체가 보이는 배율로 시작한다. 1.0 으로 시작하면 20석이 폰
  /// 폭에 안 들어가 배치도의 한 귀퉁이만 보인다. 축소 한계와 같은 배율이다.
  void _fitOnFirstLayout(SeatMapLayout layout, BoxConstraints constraints) {
    if (_fitted ||
        !constraints.hasBoundedWidth ||
        !constraints.hasBoundedHeight) {
      return;
    }
    _fitted = true;

    final scale = _fitScale(layout, constraints);

    // 빌드 도중에 컨트롤러를 건드리면 그리는 중에 값이 바뀐다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final dx = _clampAxis(
        0,
        layout.canvasWidth * scale,
        constraints.maxWidth,
      );
      final dy = _clampAxis(
        0,
        layout.canvasHeight * scale,
        constraints.maxHeight,
      );

      // z 축까지 같이 줄인다. 열 라벨이 배율을 getMaxScaleOnAxis()(세 축 중
      // 최댓값)로 읽어서, z 를 1 로 두면 배율이 1 로 읽혀 라벨만 제 크기로 남는다.
      _transform.value = Matrix4.identity()
        ..scaleByDouble(scale, scale, scale, 1)
        ..setTranslationRaw(dx, dy, 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    // 열마다 자리 수가 다르면 배치도가 사다리꼴이 된다. 그 계산에 필요한
    // 빈 칸 수를 여기서 세어 넘긴다.
    final layout = SeatMapLayout.of(
      rows: widget.seatRows,
      seatsPerRow: widget.seatsPerRow,
      place: widget.surroundings.place,
    );

    // 프레임으로 감싼다. 44px 셀이면 20석이 폰 폭에 안 들어가 화면 끝에서
    // 잘리는데, 테두리 안에서 잘리면 '창 안을 들여다보는' 것으로 보인다.
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
        // 축소 한계가 화면 크기에 달려 있으므로 제약을 알아야 한다.
        child: LayoutBuilder(
          builder: (context, constraints) {
            _fitOnFirstLayout(layout, constraints);

            final minScale = _fitScale(layout, constraints);

            return Stack(
              children: [
                InteractiveViewer(
                  transformationController: _transform,
                  // 캔버스가 화면보다 크므로 자연 크기를 그대로 쓰게 한다.
                  constrained: false,
                  minScale: minScale,
                  maxScale: 2,
                  boundaryMargin: _panBoundary(layout, constraints, minScale),
                  onInteractionEnd: (_) => _clampPan(layout, constraints),
                  child: SizedBox(
                    width: layout.canvasWidth,
                    height: layout.canvasHeight,
                    // 좌석 칸이 수백 개라 선택이 바뀔 때의 재페인트를 이 안에 가둔다.
                    child: RepaintBoundary(
                      child: _SeatCanvas(
                        layout: layout,
                        seatRows: widget.seatRows,
                        selectedSeatId: widget.selectedSeatId,
                        onSeatTap: widget.onSeatTap,
                        zoneColor: widget.zoneColor,
                        surroundings: widget.surroundings,
                      ),
                    ),
                  ),
                ),
                // 열 라벨은 가로로 밀어도 남아야 해서 캔버스 밖에 두고 세로만 따라간다.
                // top/left 만 준 Positioned 는 제약이 무제한이라 열이 많아도 안 넘친다.
                Positioned(
                  top: 0,
                  left: 0,
                  child: _PinnedRowLabels(
                    transform: _transform,
                    layout: layout,
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
            );
          },
        ),
      ),
    );
  }
}

/// 무대와 좌석을 제자리에 놓는 판. 열마다 배율과 호가 달라 [Column] 으로는 줄을
/// 세울 수 없어 자리마다 좌표를 받아 [Positioned] 로 꽂는다. 좌표 계산은 전부
/// [SeatMapLayout] 이 한다.
class _SeatCanvas extends StatelessWidget {
  const _SeatCanvas({
    required this.layout,
    required this.seatRows,
    required this.selectedSeatId,
    required this.onSeatTap,
    required this.surroundings,
    this.zoneColor,
  });

  final SeatMapLayout layout;
  final List<List<Seat?>> seatRows;
  final int? selectedSeatId;
  final void Function(Seat seat) onSeatTap;
  final Color? zoneColor;
  final ZoneSurroundings surroundings;

  /// 좌석 좌표는 열 라벨 오른쪽부터 센다.
  double get _originX => SeatMapLayout.padding.left + SeatMapLayout.labelWidth;

  @override
  Widget build(BuildContext context) {
    return Stack(
      // 맨 뒷열 양 끝이 호만큼 내려가므로 자르지 않는다.
      clipBehavior: Clip.none,
      children: [
        ...zoneBands(
          layout: layout,
          surroundings: surroundings,
          originX: _originX,
        ),
        for (var row = 0; row < seatRows.length; row++)
          for (var column = 0; column < seatRows[row].length; column++)
            // 자리가 없는 칸(통로)은 아무것도 그리지 않는다. 좌표로 놓기 때문에
            // 빈 칸을 채우지 않아도 뒤의 자리가 밀리지 않는다.
            if (seatRows[row][column] case final seat?)
              Positioned(
                left: _originX + layout.seatLeft(row, column),
                top: SeatMapLayout.padding.top + layout.rowTop(row),
                width: SeatMapLayout.cellSize,
                height: SeatMapLayout.cellSize,
                child: _SeatCell(
                  // 서버 좌석 번호. 좌석을 지목해 탭하는 테스트에 쓴다.
                  key: ValueKey(seat.id),
                  seat: seat,
                  state: seatCellStateOf(seat, selectedSeatId),
                  size: SeatMapLayout.cellSize,
                  onTap: onSeatTap,
                  zoneColor: zoneColor,
                ),
              ),
      ],
    );
  }
}

/// 구역 둘레에 놓이는 무대·이웃 구역 띠. 무대 왼편 구역은 위쪽과 오른쪽이,
/// 오른편 구역은 위쪽과 왼쪽이 무대다. 뒤쪽 구역은 앞 가운데만 무대이고 좌우로
/// 이웃 구역이 보인다. 캔버스 [Stack] 에 바로 꽂도록 [Positioned] 목록으로 준다.
List<Widget> zoneBands({
  required SeatMapLayout layout,
  required ZoneSurroundings surroundings,
  required double originX,
}) {
  final top = SeatMapLayout.padding.top;
  // 위쪽 띠는 맨 앞열에서 자리가 있는 구간에 맞춘다. 격자 전체 너비로 깔면
  // 자리 없는 쪽으로 삐져나온다.
  final left = originX + layout.frontRowLeft;
  final width = layout.frontRowWidth;
  final bands = <Widget>[];

  final frontLeft = surroundings.frontLeft;
  final frontRight = surroundings.frontRight;

  if (surroundings.place == SeatZonePlace.rear &&
      frontLeft != null &&
      frontRight != null) {
    // 앞 가운데만 무대다. 돌출부 폭을 구역도와 비슷하게 3할쯤 잡는다.
    const stageShare = 0.3;
    const gap = 6.0;
    final stageWidth = width * stageShare;
    final sideWidth = (width - stageWidth - gap * 2) / 2;

    bands.addAll([
      Positioned(
        left: left,
        top: top,
        width: sideWidth,
        height: layout.stageBandHeight,
        child: _NeighborBand(frontLeft),
      ),
      Positioned(
        left: left + sideWidth + gap,
        top: top,
        width: stageWidth,
        height: layout.stageBandHeight,
        child: const _StageBand(),
      ),
      Positioned(
        left: left + sideWidth + gap + stageWidth + gap,
        top: top,
        width: sideWidth,
        height: layout.stageBandHeight,
        child: _NeighborBand(frontRight),
      ),
    ]);
  } else {
    bands.add(
      Positioned(
        left: left,
        top: top,
        width: width,
        height: layout.stageBandHeight,
        child: const _StageBand(),
      ),
    );

    final front = surroundings.front;
    if (front != null) {
      bands.add(
        Positioned(
          left: left,
          top: top + layout.frontBandTop,
          width: width,
          height: SeatMapLayout.neighborHeight,
          child: _NeighborBand(front),
        ),
      );
    }
  }

  if (layout.hasSideStage) {
    // 옆 무대는 좌석이 있는 높이만큼만 세운다. 위쪽 띠와 이어져 'ㄱ' 자가 된다.
    final rowsTop = layout.rowTop(0);
    bands.add(
      Positioned(
        left: originX + layout.sideBandLeft,
        top: top + rowsTop,
        width: SeatMapLayout.sideBandWidth,
        height: layout.rowsBottom - rowsTop,
        child: _StageBand(
          // 글자가 무대 쪽에서 객석을 향하도록 돌린다.
          quarterTurns: layout.place == SeatZonePlace.stageLeft ? 1 : 3,
        ),
      ),
    );
  }

  return bands;
}

/// 무대 띠. 세로로 세울 때는 글자를 돌린다.
class _StageBand extends StatelessWidget {
  const _StageBand({this.quarterTurns = 0});

  final int quarterTurns;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      'STAGE',
      maxLines: 1,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: AppColors.textPrimary,
      ),
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.stageFill,
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      child: Center(
        child: quarterTurns == 0
            ? label
            : RotatedBox(quarterTurns: quarterTurns, child: label),
      ),
    );
  }
}

/// 이웃 구역 띠. 여기 앉는 게 아니라는 걸 보이려고 무대와 다르게 비워 둔다.
class _NeighborBand extends StatelessWidget {
  const _NeighborBand(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.mapSurface,
        border: Border.all(color: AppColors.border),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

/// 가로 이동과 무관하게 왼쪽에 붙어 있는 열 라벨. [InteractiveViewer] 의 변환에서
/// 세로 이동과 배율만 뽑아 적용한다.
class _PinnedRowLabels extends StatelessWidget {
  const _PinnedRowLabels({required this.transform, required this.layout});

  final TransformationController transform;
  final SeatMapLayout layout;

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
              width: SeatMapLayout.padding.left + SeatMapLayout.labelWidth,
              height: layout.canvasHeight,
              // 좌석이 이 아래로 지나가므로 불투명해야 한다.
              color: AppColors.surface,
              child: Stack(
                children: [
                  // 열 번호는 자리에서 읽지 않고 순서로 센다. 통로로 한 열이
                  // 통째로 비면 그 줄에는 읽을 좌석이 없다.
                  for (var row = 0; row < layout.rowCount; row++)
                    Positioned(
                      left: SeatMapLayout.padding.left,
                      top: SeatMapLayout.padding.top + layout.rowTop(row),
                      width: SeatMapLayout.labelWidth,
                      height: SeatMapLayout.cellSize,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${row + 1}열',
                          style: labelStyle,
                          maxLines: 1,
                        ),
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

class _SeatCell extends StatelessWidget {
  const _SeatCell({
    super.key,
    required this.seat,
    required this.state,
    required this.size,
    required this.onTap,
    this.zoneColor,
  });
  final Color? zoneColor;

  final Seat seat;
  final SeatCellState state;

  /// 이 칸의 한 변. 열마다 다르므로(앞열이 작다) 모서리도 같은 비율로 깎는다.
  final double size;

  final void Function(Seat seat) onTap;

  @override
  Widget build(BuildContext context) {
    final colors = seatCellColors(state, zoneColor: zoneColor);

    // 고를 수 없는 좌석도 탭은 받는다. 여기서 거르지 않고 화면(onTap)이
    // 판단하게 두는 것은, 자리마다 무엇을 할지가 화면의 사정이기 때문이다.
    return GestureDetector(
      onTap: () => onTap(seat),
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.fill,
          border: Border.all(
            color: colors.border,
            width: state == SeatCellState.selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.all(
            Radius.circular(size * seatCellRadiusRatio),
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
            colors: [AppColors.surface, AppColors.surface.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
