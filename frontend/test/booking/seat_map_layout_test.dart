import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/booking/models/seat.dart';
import 'package:timo/features/booking/models/zone.dart';
import 'package:timo/features/booking/widgets/seat_grid.dart';
import 'package:timo/features/booking/widgets/seat_map_layout.dart';

/// 서버 시드와 같은 크기(10열 x 20석)의 구역.
const _rowCount = 10;
const _seatsPerRow = 20;

/// 좌석 번호는 `열 * 100 + 번호`. 열을 지목해 찾을 수 있게 규칙을 둔다.
int _seatId(int row, int number) => row * 100 + number;

List<List<Seat?>> _fullZone() => [
  for (var row = 1; row <= _rowCount; row++)
    [
      for (var number = 1; number <= _seatsPerRow; number++)
        Seat(
          id: _seatId(row, number),
          row: row,
          number: number,
          status: SeatStatus.available,
        ),
    ],
];

/// 앞열이 짧은 구역. 서버가 열마다 다른 수의 좌석을 주면 이렇게 온다
/// (1열 4석, 2열 6석, 3열 8석, 4열 10석 - 좌석 번호는 열마다 1번부터).
List<List<Seat?>> _taperedZone() => [
  for (var row = 1; row <= 4; row++)
    [
      for (var number = 1; number <= 10; number++)
        number <= row * 2 + 2
            ? Seat(
                id: _seatId(row, number),
                row: row,
                number: number,
                status: SeatStatus.available,
              )
            : null,
    ],
];

SeatMapLayout _tapered(SeatZonePlace place) =>
    SeatMapLayout.of(rows: _taperedZone(), seatsPerRow: 10, place: place);

Zone _zone(int id, String name) => Zone(
  id: id,
  name: name,
  price: 100000,
  seatCount: 10,
  availableCount: 10,
  rowCount: 1,
  seatsPerRow: 10,
);

void main() {
  final layout = SeatMapLayout(rowCount: _rowCount, seatsPerRow: _seatsPerRow);

  /// 배치도를 고정 크기 화면에 그린다.
  Future<void> pumpGrid(
    WidgetTester tester, {
    Size viewport = const Size(360, 480),
    ZoneSurroundings surroundings = const ZoneSurroundings(),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: viewport.width,
              height: viewport.height,
              child: SeatGrid(
                seatsPerRow: _seatsPerRow,
                seatRows: _fullZone(),
                selectedSeatId: null,
                onSeatTap: (_) {},
                surroundings: surroundings,
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('배치 계산', () {
    test('자리가 꽉 찬 구역은 모든 열이 같은 자리에서 시작한다', () {
      // 지금 서버 데이터가 이렇다. 밀어낼 빈 칸이 없어 직사각형으로 보인다.
      expect(layout.seatLeft(0, 0), layout.seatLeft(_rowCount - 1, 0));
    });

    test('통로 자리는 앞뒤 칸보다 사이가 벌어진다', () {
      final aisle = layout.columnAisles.first;
      final between = layout.seatLeft(0, 2) - layout.seatLeft(0, 1);
      final across = layout.seatLeft(0, aisle) - layout.seatLeft(0, aisle - 1);

      expect(across, greaterThan(between));
    });

    test('가로 통로가 난 열은 그만큼 더 내려간다', () {
      final aisle = layout.rowAisles.first;
      final across = layout.rowTop(aisle) - layout.rowTop(aisle - 1);
      final between = layout.rowTop(aisle - 1) - layout.rowTop(aisle - 2);

      expect(across - between, greaterThan(SeatMapLayout.aisleDepth / 2));
    });

    test('자리가 적은 구역에는 통로를 두지 않는다', () {
      final small = SeatMapLayout(rowCount: 4, seatsPerRow: 6);

      expect(small.columnAisles, isEmpty);
      expect(small.rowAisles, isEmpty);
    });

    test('한 열짜리 구역도 계산이 무너지지 않는다', () {
      final single = SeatMapLayout(rowCount: 1, seatsPerRow: 1);

      expect(single.seatLeft(0, 0), single.contentLeft);
      expect(single.canvasHeight, greaterThan(0));
    });
  });

  group('열마다 자리 수가 다르면', () {
    /// [row] 에서 자리가 놓인 구간의 오른쪽 끝.
    double rightEdge(SeatMapLayout layout, int row) =>
        layout.occupiedSpan(row).left + layout.occupiedSpan(row).width;

    test('칸 크기는 그대로고 짧은 열이 밀린다', () {
      final rear = _tapered(SeatZonePlace.rear);

      // 1열(4석)과 4열(10석)의 칸 간격이 같다 - 칸을 줄이지 않는다.
      expect(
        rear.seatLeft(0, 1) - rear.seatLeft(0, 0),
        closeTo(rear.seatLeft(3, 1) - rear.seatLeft(3, 0), 0.01),
      );
      // 짧은 열은 그만큼 좁다.
      expect(rear.occupiedSpan(0).width, lessThan(rear.occupiedSpan(3).width));
    });

    test('뒤쪽 구역은 짧은 열을 가운데에 둔다', () {
      final rear = _tapered(SeatZonePlace.rear);
      final left = rear.occupiedSpan(0).left - rear.occupiedSpan(3).left;
      final right = rightEdge(rear, 3) - rightEdge(rear, 0);

      expect(left, closeTo(right, 0.01));
    });

    test('무대 왼편 구역은 짧은 열을 오른쪽에 붙인다', () {
      final a = _tapered(SeatZonePlace.stageLeft);

      expect(rightEdge(a, 0), closeTo(rightEdge(a, 3), 0.01));
    });

    test('무대 오른편 구역은 짧은 열을 왼쪽에 붙인다', () {
      final b = _tapered(SeatZonePlace.stageRight);

      expect(b.occupiedSpan(0).left, closeTo(b.occupiedSpan(3).left, 0.01));
    });

    test('2층도 무대 쪽으로 붙인다', () {
      expect(
        rightEdge(_tapered(SeatZonePlace.balconyLeft), 0),
        closeTo(rightEdge(_tapered(SeatZonePlace.balconyLeft), 3), 0.01),
      );
      expect(
        _tapered(SeatZonePlace.balconyRight).occupiedSpan(0).left,
        closeTo(
          _tapered(SeatZonePlace.balconyRight).occupiedSpan(3).left,
          0.01,
        ),
      );
    });

    test('2층은 무대 띠 아래 앞 구역 띠가 하나 더 들어간다', () {
      expect(
        _tapered(SeatZonePlace.balconyLeft).frontDepth,
        greaterThan(_tapered(SeatZonePlace.rear).frontDepth),
      );
    });
  });

  group('구역 둘레 읽기', () {
    final zones = [
      _zone(1, 'A구역'),
      _zone(2, 'B구역'),
      _zone(3, 'C구역'),
      _zone(4, '2층 D구역'),
      _zone(5, '2층 E구역'),
    ];

    test('목록 순서대로 자리를 정한다', () {
      expect(ZoneSurroundings.of(zones, 1).place, SeatZonePlace.stageLeft);
      expect(ZoneSurroundings.of(zones, 2).place, SeatZonePlace.stageRight);
      expect(ZoneSurroundings.of(zones, 3).place, SeatZonePlace.rear);
      expect(ZoneSurroundings.of(zones, 4).place, SeatZonePlace.balconyLeft);
      expect(ZoneSurroundings.of(zones, 5).place, SeatZonePlace.balconyRight);
    });

    test('뒤쪽 구역은 앞 좌우 구역 이름을 들고 온다', () {
      final rear = ZoneSurroundings.of(zones, 3);

      expect(rear.frontLeft, 'A구역');
      expect(rear.frontRight, 'B구역');
    });

    test('2층은 바로 앞 구역 이름을 들고 온다', () {
      expect(ZoneSurroundings.of(zones, 4).front, 'C구역');
    });

    test('구역 목록이 없으면 무대만 있는 기본 모습으로 돌아간다', () {
      final unknown = ZoneSurroundings.of(const [], 1);

      expect(unknown.place, SeatZonePlace.rear);
      expect(unknown.frontLeft, isNull);
      expect(unknown.front, isNull);
    });
  });

  testWidgets('좌석은 어느 열에서나 44px 이다', (tester) async {
    await pumpGrid(tester);

    final sizes = {
      for (final row in [1, 5, _rowCount])
        for (final number in [1, _seatsPerRow])
          tester.getSize(find.byKey(ValueKey(_seatId(row, number)))),
    };

    // 사다리꼴을 만들려고 칸을 줄이지 않는다. 열마다 길이가 달라지는 것은
    // 자리 수가 다를 때뿐이다.
    expect(sizes, {const Size(SeatMapLayout.cellSize, SeatMapLayout.cellSize)});
  });

  testWidgets('맨 앞줄은 수평이다', (tester) async {
    await pumpGrid(tester);

    final tops = {
      for (var number = 1; number <= _seatsPerRow; number++)
        tester.getTopLeft(find.byKey(ValueKey(_seatId(1, number)))).dy,
    };

    // 한 열의 자리가 모두 같은 높이여야 한다. 무대를 감싸듯 굽히면 가운데가
    // 볼록 튀어나와 배치도가 기울어 보인다.
    expect(tops.length, 1);
  });

  testWidgets('구역마다 무대가 다른 자리에 붙는다', (tester) async {
    await pumpGrid(
      tester,
      surroundings: const ZoneSurroundings(place: SeatZonePlace.stageLeft),
    );
    // 무대 왼편 구역: 위쪽 띠 + 오른쪽 띠.
    expect(find.text('STAGE'), findsNWidgets(2));

    await pumpGrid(
      tester,
      surroundings: const ZoneSurroundings(
        place: SeatZonePlace.rear,
        frontLeft: 'A구역',
        frontRight: 'B구역',
      ),
    );
    // 뒤쪽 구역: 앞 가운데만 무대이고 좌우는 이웃 구역이다.
    expect(find.text('STAGE'), findsOneWidget);
    expect(find.text('A구역'), findsOneWidget);
    expect(find.text('B구역'), findsOneWidget);

    await pumpGrid(
      tester,
      surroundings: const ZoneSurroundings(
        place: SeatZonePlace.balconyLeft,
        front: 'C구역',
      ),
    );
    expect(find.text('STAGE'), findsOneWidget);
    expect(find.text('C구역'), findsOneWidget);
  });

  testWidgets('처음부터 구역 전체가 보이는 배율로 시작한다', (tester) async {
    const viewport = Size(360, 480);
    await pumpGrid(tester, viewport: viewport);
    // 배율 맞추기는 첫 프레임 뒤에 일어난다.
    await tester.pump();

    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final matrix = viewer.transformationController!.value;
    final scale = matrix.getMaxScaleOnAxis();

    // 축소 한계와 같은 배율로 시작한다.
    expect(scale, closeTo(viewer.minScale, 0.001));
    expect(scale, lessThan(1));
    // 그 배율에서 배치도가 화면에 다 들어온다.
    expect(layout.canvasWidth * scale, lessThanOrEqualTo(viewport.width + 0.5));
    expect(
      layout.canvasHeight * scale,
      lessThanOrEqualTo(viewport.height + 0.5),
    );
  });

  testWidgets('배치도를 화면 밖으로 밀어도 손을 떼면 돌아온다', (tester) async {
    await pumpGrid(tester);

    final grid = tester.getRect(find.byType(InteractiveViewer));
    // 축소 한계를 받치는 경계 여백 때문에 한 화면 넘게 밀린다.
    await tester.drag(find.byType(InteractiveViewer), const Offset(0, 1200));
    await tester.pumpAndSettle();

    // 가운데 자리로 본다. 1열 첫 자리는 밀지 않아도 원래 가로로 화면 밖이다.
    final seat = tester.getRect(
      find.byKey(ValueKey(_seatId(1, _seatsPerRow ~/ 2))),
    );
    expect(grid.overlaps(seat), isTrue, reason: '밀어낸 뒤에도 배치도가 화면에 남아 있어야 한다');
  });

  testWidgets('가장 작게 줄이면 구역 전체가 화면에 들어온다', (tester) async {
    const viewport = Size(360, 480);
    await pumpGrid(tester, viewport: viewport);

    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );

    // 축소 한계까지 줄이면 배치도가 화면 안에 다 들어와야 한다.
    expect(
      viewer.minScale * layout.canvasWidth,
      lessThanOrEqualTo(viewport.width + 0.5),
    );
    expect(
      viewer.minScale * layout.canvasHeight,
      lessThanOrEqualTo(viewport.height + 0.5),
    );
    // 이 구역은 화면보다 크므로 축소 한계는 1.0 보다 작아야 한다.
    expect(viewer.minScale, lessThan(1));

    // 경계 여백이 좁으면 InteractiveViewer 는 배치도가 화면을 꽉 채우는 배율에서
    // 멈춰 축소 한계까지 못 줄인다. 여백이 한계까지 받쳐 주는지 본다.
    final margin = viewer.boundaryMargin;
    final reachable = math.max(
      viewport.width / (layout.canvasWidth + margin.horizontal),
      viewport.height / (layout.canvasHeight + margin.vertical),
    );
    expect(reachable, lessThanOrEqualTo(viewer.minScale + 0.001));
  });
}
