import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/theme/app_theme.dart';
import 'package:timo/features/booking/data/mock_booking_api.dart';
import 'package:timo/features/booking/models/performance.dart';
import 'package:timo/features/booking/models/seat.dart';
import 'package:timo/features/booking/models/zone.dart';
import 'package:timo/features/booking/screens/seat_selection_screen.dart';
import 'package:timo/features/booking/state/booking_api_scope.dart';
import 'package:timo/features/booking/state/booking_controller.dart';
import 'package:timo/features/booking/state/booking_scope.dart';

import 'package:timo/features/booking/widgets/venue_map.dart';
import 'package:timo/features/booking/widgets/zone_info_panels.dart';

void main() {
  const zones = [
    Zone(
      id: 1,
      name: 'A구역',
      price: 100000,
      seatCount: 2,
      availableCount: 2,
      rowCount: 1,
      seatsPerRow: 2,
    ),
    Zone(
      id: 2,
      name: 'B구역',
      price: 100000,
      seatCount: 2,
      availableCount: 0,
      rowCount: 1,
      seatsPerRow: 2,
    ),
  ];

  testWidgets('잔여석 목록 행은 해당 구역을 전달한다', (tester) async {
    Zone? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RemainingSeatsPanel(
            zones: zones,
            onZoneTap: (zone) => selected = zone,
          ),
        ),
      ),
    );
    await tester.tap(find.text('A구역'));
    expect(selected?.id, 1);
    expect(find.text('매진'), findsOneWidget);
  });

  testWidgets('잔여석 안내 덧붙임은 물음표를 눌러야 펴진다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RemainingSeatsPanel(zones: zones)),
      ),
    );

    const hint = '선점 중인 좌석이 있어 실제로 고를 수 있는 자리는 더 적을 수 있어요.';
    expect(find.text(hint), findsNothing);

    // 아이콘으로 찾는다. bySemanticsLabel 은 시맨틱 트리를 켜야 걸린다.
    await tester.tap(find.byIcon(Icons.help_outline));
    await tester.pump();
    expect(find.text(hint), findsOneWidget);

    await tester.tap(find.byIcon(Icons.help));
    await tester.pump();
    expect(find.text(hint), findsNothing);
  });

  testWidgets('기존 배치도 구역은 한 개 또는 여러 개여도 탭할 수 있다', (tester) async {
    for (final items in [zones.take(1).toList(), zones]) {
      Zone? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: VenueMap(
                zones: items,
                onZoneTap: (zone) => selected = zone,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('A구역'));
      expect(selected?.id, 1);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('미니맵과 구역 이름 스와이프로 이동 후 이전 선택을 지운다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final api = MockBookingApi(latency: Duration.zero);
    final allZones = await api.fetchZones(1);
    final controller = BookingController(
      performance: Performance(
        title: '테스트 공연',
        venue: '테스트홀',
        startAt: DateTime(2026, 11, 4),
      ),
    );
    addTearDown(controller.dispose);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RepaintBoundary(
          key: boundaryKey,
          child: BookingApiScope(
            api: api,
            child: BookingScope(
              controller: controller,
              child: SeatSelectionScreen(zoneId: allZones.first.id),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final firstSeats = await api.fetchSeats(
      concertId: 1,
      zoneId: allZones.first.id,
    );
    final available = firstSeats.rows
        .expand((r) => r)
        .whereType<Seat>()
        .firstWhere((s) => s.isSelectable);
    controller.selectSeat(allZones.first, available);
    await tester.pump();
    await tester.fling(
      find.byKey(const ValueKey('zone-navigation')),
      const Offset(-100, 0),
      500,
    );
    await tester.pumpAndSettle();
    expect(controller.selectedSeat, isNull);
    expect(
      tester.widget<VenueMap>(find.byType(VenueMap).first).selectedZoneId,
      allZones[1].id,
    );
    await tester.tap(find.bySemanticsLabel('전체 배치도에서 구역 변경'));
    await tester.pumpAndSettle();
    expect(find.text('이동할 구역을 선택하세요'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, allZones.first.name));
    await tester.pumpAndSettle();
    expect(
      tester.widget<VenueMap>(find.byType(VenueMap).first).selectedZoneId,
      allZones.first.id,
    );
    expect(tester.takeException(), isNull);

    // Optional local visual review, kept out of the source tree.
    if (const bool.fromEnvironment('CAPTURE_SEAT_REVIEW')) {
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/seat-design-review.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
