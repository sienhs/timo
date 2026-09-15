import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/network/api_exception.dart';
import 'package:timo/core/theme/app_theme.dart';
import 'package:timo/features/booking/data/booking_api.dart';
import 'package:timo/features/booking/models/performance.dart';
import 'package:timo/features/booking/models/seat.dart';
import 'package:timo/features/booking/models/seat_hold.dart';
import 'package:timo/features/booking/models/zone.dart';
import 'package:timo/features/booking/models/zone_seats.dart';
import 'package:timo/features/booking/screens/seat_selection_screen.dart';
import 'package:timo/features/booking/state/booking_api_scope.dart';
import 'package:timo/features/booking/state/booking_controller.dart';
import 'package:timo/features/booking/state/booking_scope.dart';
import 'package:timo/routes/app_routes.dart';

/// 고정 배치도(랜덤 시드)에 기대면 어느 좌석이 예매 가능한지 알 수 없으므로
/// 테스트는 직접 만든 최소 좌석 배치를 쓴다.
/// 1열에 예매가능 · 선점중 · 예매완료를 하나씩 둔다.
final _zoneSeats = ZoneSeats(
  zoneId: 1,
  zoneName: '1층 A블록',
  price: 100000,
  seatCount: 3,
  availableCount: 1,
  rows: const [
    [
      Seat(id: 11, row: 1, number: 1, status: SeatStatus.available),
      Seat(id: 12, row: 1, number: 2, status: SeatStatus.held),
      Seat(id: 13, row: 1, number: 3, status: SeatStatus.sold),
    ],
  ],
);

/// 정해진 배치도 하나만 돌려주는 가짜 API.
class _FakeBookingApi implements BookingApi {
  int fetchCount = 0;
  final held = <int>[];
  final cancelled = <int>[];

  /// 선점 요청에 던질 실패. null 이면 성공한다.
  ApiException? holdError;

  @override
  Future<List<Zone>> fetchZones(int concertId) async => const [];

  @override
  Future<ZoneSeats> fetchSeats({
    required int concertId,
    required int zoneId,
  }) async {
    fetchCount++;
    return _zoneSeats;
  }

  @override
  Future<SeatHold> holdSeat({
    required int concertId,
    required int seatId,
  }) async {
    final error = holdError;
    if (error != null) throw error;
    held.add(seatId);
    final now = DateTime.now();
    return SeatHold(
      seatId: seatId,
      expiresAt: now.add(const Duration(minutes: 5)),
      heldAt: now,
    );
  }

  @override
  Future<void> cancelHold({required int concertId, required int seatId}) async {
    cancelled.add(seatId);
  }
}

BookingController _buildController() => BookingController(
  performance: Performance(
    title: '테스트 공연',
    venue: '테스트홀',
    startAt: DateTime(2026, 11, 4, 18),
    bookingFee: 3000,
  ),
);

Widget _app(BookingController controller, BookingApi api) => MaterialApp(
  theme: AppTheme.light,
  home: BookingApiScope(
    api: api,
    child: BookingScope(
      controller: controller,
      child: const SeatSelectionScreen(zoneId: 1),
    ),
  ),
  // 선점이 성공하면 결제로, 인증이 막히면 로그인으로 간다. 목적지가 없으면
  // 이동 자체가 실패하므로 자리만 세워 둔다.
  routes: {
    // AppBar 를 두는 이유: 뒤로 가기 버튼이 있어야 tester.pageBack() 이 된다.
    AppRoutes.payment: (_) =>
        Scaffold(appBar: AppBar(), body: const Text('결제 화면')),
    AppRoutes.login: (_) =>
        Scaffold(appBar: AppBar(), body: const Text('로그인 화면')),
  },
);

void main() {
  late BookingController controller;
  late _FakeBookingApi api;

  setUp(() {
    controller = _buildController();
    api = _FakeBookingApi();
    addTearDown(controller.dispose);
  });

  /// 좌석을 받아 와 배치도가 그려질 때까지 기다린다.
  Future<void> pumpSeats(WidgetTester tester) async {
    await tester.pumpWidget(_app(controller, api));
    await tester.pumpAndSettle();
  }

  /// 스낵바는 프레임 하나로는 트리에 들어오지 않는다.
  Future<void> settleSnackBar(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('좌석을 고르면 하단 바에 좌석명과 결제 금액이 찍힌다', (tester) async {
    await pumpSeats(tester);

    expect(find.text('좌석을 선택해주세요'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey(11)));
    await tester.pump();

    // 좌석 이름은 구역 이름으로 만든다. 서버가 주는 이름이 그대로 들어간다.
    expect(find.text('1층 A블록 1열 1번'), findsOneWidget);
    // 정가 100,000 + 예매 수수료 3,000
    expect(find.text('103,000원'), findsOneWidget);
    expect(controller.selectedSeat?.id, 11);
  });

  // 회색 자리를 눌렀을 때 안내를 띄우지 않는 게 의도다. 고를 수 없다는 것이
  // 색으로 이미 보이고, 배치도를 훑다 회색을 스치듯 누르는 일이 잦다.
  testWidgets('예매 완료 좌석은 눌러도 아무 일이 없다', (tester) async {
    await pumpSeats(tester);

    await tester.tap(find.byKey(const ValueKey(13)));
    await settleSnackBar(tester);

    expect(find.byType(SnackBar), findsNothing);
    expect(controller.selectedSeat, isNull);
  });

  testWidgets('남이 잡고 있는 좌석도 눌러도 아무 일이 없다', (tester) async {
    await pumpSeats(tester);

    await tester.tap(find.byKey(const ValueKey(12)));
    await settleSnackBar(tester);

    expect(find.byType(SnackBar), findsNothing);
    expect(controller.selectedSeat, isNull);
  });

  testWidgets('구역 이름을 서버 응답에서 받아 화면에 찍는다', (tester) async {
    await pumpSeats(tester);

    expect(find.textContaining('1층 A블록'), findsWidgets);
  });

  testWidgets('새로고침을 누르면 좌석을 다시 받아 온다', (tester) async {
    await pumpSeats(tester);
    expect(api.fetchCount, 1);

    await tester.tap(find.byTooltip('좌석 정보 새로고침'));
    await tester.pumpAndSettle();

    expect(api.fetchCount, 2);
  });

  group('선점', () {
    /// 좌석을 고르고 결제하기 → 확인 다이얼로그에서 [agree] 를 누른다.
    Future<void> checkout(WidgetTester tester, {bool agree = true}) async {
      await tester.tap(find.byKey(const ValueKey(11)));
      await tester.pump();
      await tester.tap(find.text('결제하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(agree ? '예' : '아니요'));
      await tester.pumpAndSettle();
    }

    testWidgets('확인을 눌러야 자리를 잡는다', (tester) async {
      await pumpSeats(tester);

      // 좌석을 고르는 것만으로는 서버에 아무것도 보내지 않는다.
      await tester.tap(find.byKey(const ValueKey(11)));
      await tester.pump();
      expect(api.held, isEmpty);

      await checkout(tester);

      expect(api.held, [11]);
      expect(controller.hold?.seatId, 11);
      expect(find.text('결제 화면'), findsOneWidget);
    });

    testWidgets('아니요를 누르면 잡지 않는다', (tester) async {
      await pumpSeats(tester);

      await checkout(tester, agree: false);

      expect(api.held, isEmpty);
      expect(controller.hold, isNull);
    });

    testWidgets('결제하지 않고 돌아오면 잡아 둔 자리를 푼다', (tester) async {
      await pumpSeats(tester);
      await checkout(tester);
      expect(controller.hold?.seatId, 11);

      // 결제 화면에서 뒤로.
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(api.cancelled, [11]);
      expect(controller.hold, isNull);
      // 고른 자리는 남는다. 자리가 다시 비었으니 한 번 더 누르면 다시 잡힌다.
      expect(controller.selectedSeat?.id, 11);
    });

    // 초록 자리를 눌러 잡으려는데 그 사이 남이 채 간 경우다. 회색 자리를
    // 누른 것과 달리 여기서는 알려 줘야 한다 — 빈 자리로 보였기 때문이다.
    testWidgets('남이 먼저 가져갔으면 안내하고 배치도를 다시 받는다', (tester) async {
      await pumpSeats(tester);
      api.holdError = const ApiException('이미 선택된 좌석입니다.', status: 409);

      await checkout(tester);

      expect(find.text('이미 선점된 좌석입니다.'), findsOneWidget);
      expect(controller.selectedSeat, isNull);
      expect(api.fetchCount, 2);
      expect(find.text('결제 화면'), findsNothing);
    });

    testWidgets('로그인이 안 돼 있으면 로그인 화면으로 보낸다', (tester) async {
      await pumpSeats(tester);
      api.holdError = const ApiException('인증 정보가 올바르지 않습니다.', status: 401);

      await checkout(tester);

      expect(find.text('로그인 화면'), findsOneWidget);
      // 고른 자리는 그대로 둔다. 로그인하고 돌아와 한 번 더 누르면 된다.
      expect(controller.selectedSeat?.id, 11);
    });
  });
}
