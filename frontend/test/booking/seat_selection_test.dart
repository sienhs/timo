import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/theme/app_theme.dart';
import 'package:timo/features/booking/models/performance.dart';
import 'package:timo/features/booking/models/seat.dart';
import 'package:timo/features/booking/models/zone.dart';
import 'package:timo/features/booking/screens/seat_selection_screen.dart';
import 'package:timo/features/booking/state/booking_controller.dart';
import 'package:timo/features/booking/state/booking_scope.dart';

/// 목업 데이터(랜덤 시드)에 기대면 어느 좌석이 예매 가능한지 알 수 없으므로
/// 테스트는 직접 만든 최소 좌석 배치를 쓴다.
const _zone = Zone(
  id: 'A',
  name: 'FLOOR A',
  price: 100000,
  rowCount: 1,
  seatsPerRow: 3,
);

BookingController _buildController() => BookingController(
      performance: Performance(
        title: '테스트 공연',
        venue: '테스트홀',
        startAt: DateTime(2026, 11, 4, 18),
        posterAsset: 'assets/images/sample_poster.jpg',
        bookingFee: 3000,
      ),
      zones: const [_zone],
      seatRowsByZone: const {
        'A': [
          [
            Seat(zoneId: 'A', row: 1, number: 1, status: SeatStatus.available),
            Seat(zoneId: 'A', row: 1, number: 2, status: SeatStatus.available),
            Seat(zoneId: 'A', row: 1, number: 3, status: SeatStatus.sold),
          ],
        ],
      },
    );

Widget _app(BookingController controller) => MaterialApp(
      theme: AppTheme.light,
      home: BookingScope(
        controller: controller,
        child: const SeatSelectionScreen(zoneId: 'A'),
      ),
    );

void main() {
  late BookingController controller;

  setUp(() {
    controller = _buildController();
    addTearDown(controller.dispose);
  });

  /// 스낵바는 프레임 하나로는 트리에 들어오지 않는다.
  Future<void> settleSnackBar(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('좌석을 고르면 하단 바에 좌석명과 결제 금액이 찍힌다', (tester) async {
    await tester.pumpWidget(_app(controller));

    expect(find.text('좌석을 선택해주세요'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('A-1-1')));
    await tester.pump();

    expect(find.text('A구역 1열 1번'), findsOneWidget);
    // 정가 100,000 + 예매 수수료 3,000
    expect(find.text('103,000원'), findsOneWidget);
    expect(controller.selectedSeat?.id, 'A-1-1');
  });

  testWidgets('1인 1매 제약대로 새 좌석을 고르면 이전 선택이 풀린다', (tester) async {
    await tester.pumpWidget(_app(controller));

    await tester.tap(find.byKey(const ValueKey('A-1-1')));
    await tester.pump();
    expect(controller.selectedSeat?.id, 'A-1-1');

    await tester.tap(find.byKey(const ValueKey('A-1-2')));
    await tester.pump();
    expect(controller.selectedSeat?.id, 'A-1-2');
    expect(find.text('A구역 1열 2번'), findsOneWidget);
  });

  testWidgets('예매 완료 좌석은 사유를 안내하고 선택되지 않는다', (tester) async {
    await tester.pumpWidget(_app(controller));

    await tester.tap(find.byKey(const ValueKey('A-1-3')));
    await settleSnackBar(tester);

    expect(find.text('이미 예매가 완료된 좌석이에요.'), findsOneWidget);
    expect(controller.selectedSeat, isNull);
  });
}
