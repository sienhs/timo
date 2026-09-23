import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timo/core/network/api_exception.dart';
import 'package:timo/core/network/server_errors.dart';
import 'package:timo/core/widgets/timo_mascot.dart';
import 'package:timo/features/booking/models/performance.dart';
import 'package:timo/features/booking/models/seat.dart';
import 'package:timo/features/booking/models/seat_hold.dart';
import 'package:timo/features/booking/models/zone.dart';
import 'package:timo/features/booking/state/booking_controller.dart';
import 'package:timo/features/booking/state/booking_scope.dart';
import 'package:timo/features/home/data/mock_home_api.dart';
import 'package:timo/features/home/state/home_api_scope.dart';
import 'package:timo/features/payment/constants.dart';
import 'package:timo/features/payment/models/ticket_order.dart';
import 'package:timo/features/payment/screens/payment_complete_screen.dart';
import 'package:timo/features/payment/screens/payment_screen.dart';
import 'package:timo/features/payment/widgets/order_summary_card.dart';
import 'package:timo/features/payment/widgets/ticket_issuing_view.dart';
import 'package:timo/features/ticket/data/ticket_api.dart';
import 'package:timo/features/ticket/models/entry_pass.dart';
import 'package:timo/features/ticket/models/my_ticket.dart';
import 'package:timo/features/ticket/models/reservation_detail.dart';
import 'package:timo/features/ticket/models/reservation_status.dart';
import 'package:timo/features/ticket/state/ticket_api_scope.dart';
import 'package:timo/routes/app_routes.dart';

/// 폰 화면 크기. 이보다 좁아지면 레이아웃이 깨지는지 확인하는 기준이 된다.
const _phoneSize = Size(375, 812);

/// 결제 화면을 띄우는 자리(앱에서는 좌석 화면)의 라우트 이름.
const _launcherRoute = '/launcher';

/// 주문 요청을 기록하는 가짜 예매 API. [failure] 를 넣으면 주문 생성이 그걸 던진다.
class _FakeTicketApi implements TicketApi {
  final created = <({int concertId, int seatId})>[];
  ApiException? failure;

  /// 주문 상세를 물을 때마다 순서대로 돌려준다. 다 쓰면 마지막 것을 반복하고,
  /// 비어 있으면 "발행 중" 이다. [ApiException] 을 넣으면 그 차례에 던진다.
  final pollResponses = <Object>[];

  /// 주문 상세를 몇 번 물었는가.
  int polls = 0;

  /// 주문 상세 응답이 늦는 정도. 되묻는 주기보다 길게 주면 중간 주기들이
  /// 그냥 넘어가는 상황(요청이 아직 나가 있는 상태)을 만든다.
  Duration latency = Duration.zero;

  @override
  Future<ReservationDetail> createReservation({
    required int concertId,
    required int seatId,
  }) async {
    if (failure case final failure?) throw failure;
    created.add((concertId: concertId, seatId: seatId));
    return detail(concertId: concertId);
  }

  @override
  Future<ReservationDetail> fetchReservation(int reservationId) async {
    final index = polls++;
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (pollResponses.isEmpty) return detail();
    final response =
        pollResponses[index < pollResponses.length
            ? index
            : pollResponses.length - 1];
    if (response is ApiException) throw response;
    return response as ReservationDetail;
  }

  @override
  Future<List<MyTicket>> fetchMyTickets() async => const [];

  @override
  Future<void> cancelReservation(int reservationId) async {}

  /// 결제 흐름은 입장 QR 을 부르지 않는다. 불리면 테스트가 잘못된 것이다.
  @override
  Future<EntryPass> issueEntryPass(int ticketId) =>
      throw UnimplementedError('결제 흐름은 입장 QR 을 발급하지 않는다');

  /// 주문 상세 한 건. 아무것도 안 넘기면 발행 중이다.
  static ReservationDetail detail({
    int concertId = 3,
    ReservationStatus status = ReservationStatus.paid,
    String? tokenId,
    String? failureReason,
  }) => ReservationDetail(
    reservationId: 7,
    concertId: concertId,
    title: '로이킴 콘서트',
    venueName: '고척돔',
    sectionName: 'A구역',
    seatRow: 1,
    seatNumber: 9,
    facePrice: 150000,
    status: status,
    tokenId: tokenId,
    failureReason: failureReason,
  );
}

/// 좌석 화면 자리. 결제 화면을 띄우고 돌아온 결과를 [results] 에 남긴다.
class _Launcher extends StatelessWidget {
  const _Launcher({required this.results});

  final List<Object?> results;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () async {
            results.add(await Navigator.pushNamed(context, AppRoutes.payment));
          },
          child: const Text('결제 화면으로'),
        ),
      ),
    );
  }
}

/// 공연 3번의 A구역 1열 9번(좌석 1009)을 잡아 둔 예매 상태.
BookingController _heldBooking() {
  final controller =
      BookingController(
          performance: Performance(
            title: '로이킴 콘서트',
            venue: '고척돔',
            startAt: DateTime(2026, 9, 20, 19, 30),
          ),
        )
        ..startBooking(3)
        ..selectSeat(
          const Zone(
            id: 1,
            name: 'A구역',
            price: 150000,
            seatCount: 200,
            availableCount: 100,
            rowCount: 10,
            seatsPerRow: 20,
          ),
          const Seat(id: 1009, row: 1, number: 9, status: SeatStatus.available),
        );
  final now = DateTime.now();
  controller.holdSeat(
    SeatHold(
      seatId: 1009,
      price: 150000,
      expiresAt: now.add(const Duration(minutes: 5)),
      heldAt: now,
    ),
  );
  return controller;
}

/// 예매 흐름 없이 라우트만 띄운다. 디자인 확인 · 딥링크로 열린 경우다.
Future<void> _pumpApp(WidgetTester tester, String initialRoute) async {
  await tester.binding.setSurfaceSize(_phoneSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  // 완료 화면의 '홈으로' 가 홈으로 가고, 홈 탭은 공연 API 를 위에서 찾는다.
  // 앱처럼 스코프로 감싼다.
  await tester.pumpWidget(
    HomeApiScope(
      api: const MockHomeApi(latency: Duration.zero),
      child: MaterialApp(initialRoute: initialRoute, routes: AppRoutes.routes),
    ),
  );
}

/// 자리를 잡아 둔 예매 흐름 안에서 결제 화면을 띄운다. 좌석 화면 자리에서
/// 결제 화면으로 들어간 상태로 끝난다.
Future<void> _pumpFlow(
  WidgetTester tester, {
  required _FakeTicketApi api,
  required BookingController booking,
  required List<Object?> results,
}) async {
  await tester.binding.setSurfaceSize(_phoneSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    HomeApiScope(
      api: const MockHomeApi(latency: Duration.zero),
      child: TicketApiScope(
        api: api,
        child: BookingScope(
          controller: booking,
          child: MaterialApp(
            initialRoute: _launcherRoute,
            routes: {
              ...AppRoutes.routes,
              _launcherRoute: (_) => _Launcher(results: results),
            },
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('결제 화면으로'));
  await _settleTransition(tester);
}

/// 화면 전환 애니메이션만큼 기다린다.
///
/// `pumpAndSettle` 을 쓰지 않는다. 결제 화면의 카운트다운이 매초 프레임을
/// 예약해 끝나지 않는다. 기본 전환(Material 3 의 FadeForwards)이 800ms 라
/// 1초를 보내고, 마지막 `pump` 는 애니메이션이 끝난 뒤 밀려난 화면이 트리에서
/// 빠지는 프레임이다.
Future<void> _settleTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

void main() {
  testWidgets('결제 화면에 주문 요약과 합계 금액이 표시된다', (WidgetTester tester) async {
    await _pumpApp(tester, AppRoutes.payment);

    expect(
      find.text(PaymentConstants.sampleOrder.concertTitle),
      findsOneWidget,
    );
    expect(find.text(PaymentConstants.totalLabel), findsOneWidget);
    // 수수료가 없어 티켓 가격 줄과 TOTAL 줄이 같은 금액이다.
    expect(find.text('186,000원'), findsNWidgets(2));
  });

  group('예매자 성함 줄', () {
    Future<void> pumpCard(WidgetTester tester, String? bookerName) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OrderSummaryCard(
                order: TicketOrder(
                  concertTitle: '테스트 공연',
                  performedAt: DateTime(2026, 11, 4, 18),
                  venue: '테스트홀',
                  seat: 'A구역 1열 1번',
                  bookerName: bookerName,
                  ticketPrice: 100000,
                ),
              ),
            ),
          ),
        );

    testWidgets('이름을 받았으면 라벨과 함께 찍는다', (WidgetTester tester) async {
      await pumpCard(tester, '김예매');

      expect(find.text(PaymentConstants.bookerLabel), findsOneWidget);
      expect(find.text('김예매'), findsOneWidget);
    });

    // 빈 값을 둔 줄은 '이름이 비어 있다' 로 읽혀 잘못 예매된 것처럼 보인다.
    testWidgets('이름을 못 받았으면 줄째로 뺀다', (WidgetTester tester) async {
      await pumpCard(tester, null);

      expect(find.text(PaymentConstants.bookerLabel), findsNothing);
    });
  });

  // 예매 흐름 밖에서 열린 결제 화면이다. 서버에 만들 주문이 없으니 부르지
  // 않고 완료 화면만 보여 준다. 이 덕에 예매 API 스코프 없이도 라우트가 뜬다.
  testWidgets('잡아 둔 자리가 없으면 서버를 부르지 않고 완료 화면으로 넘어간다', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, AppRoutes.payment);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.byType(PaymentCompleteScreen), findsOneWidget);
    expect(find.byType(PaymentScreen), findsNothing);
  });

  testWidgets('완료 화면에 성공 문구와 예약 정보가 표시된다', (WidgetTester tester) async {
    await _pumpApp(tester, AppRoutes.paymentComplete);

    expect(find.text(PaymentConstants.completeTitle), findsOneWidget);
    expect(find.text(PaymentConstants.issuingBadgeLabel), findsOneWidget);
    expect(find.text(PaymentConstants.seatLabel), findsOneWidget);
    expect(find.text(PaymentConstants.viewTicketLabel), findsOneWidget);
    expect(find.text(PaymentConstants.goHomeLabel), findsOneWidget);
  });

  group('주문 생성', () {
    late _FakeTicketApi api;
    late BookingController booking;
    late List<Object?> results;

    setUp(() {
      api = _FakeTicketApi();
      booking = _heldBooking();
      results = [];
      addTearDown(booking.dispose);
    });

    Future<void> pay(WidgetTester tester) async {
      await tester.tap(find.byType(FilledButton));
      await _settleTransition(tester);
    }

    testWidgets('잡아 둔 자리의 공연·좌석 번호로 주문을 만들고 완료 화면으로 간다', (tester) async {
      await _pumpFlow(tester, api: api, booking: booking, results: results);
      // 잡은 자리의 값이 결제 금액이다.
      expect(find.text('150,000원'), findsNWidgets(2));

      await pay(tester);

      expect(api.created, [(concertId: 3, seatId: 1009)]);
      expect(find.byType(PaymentCompleteScreen), findsOneWidget);
      expect(find.byType(PaymentScreen), findsNothing);
      // 결제 화면을 띄운 쪽(좌석 화면)에 주문이 됐다고 알린다. 그쪽이 이 값을
      // 보고 잡아 둔 자리를 풀지 않는다.
      expect(results, [true]);
    });

    // 우리가 문구를 붙이지 못한 거절이다. 뭉뚱그리면 원인을 알 길이 없어지므로
    // 서버 문구를 그대로 띄운다.
    testWidgets('모르는 사유로 거절하면 서버 문구를 띄우고 좌석 화면으로 돌아간다', (tester) async {
      await _pumpFlow(tester, api: api, booking: booking, results: results);
      api.failure = const ApiException('결제할 수 없는 주문입니다.', status: 409);

      await pay(tester);

      expect(find.text('결제할 수 없는 주문입니다.'), findsOneWidget);
      expect(find.byType(PaymentScreen), findsNothing);
      expect(find.text('결제 화면으로'), findsOneWidget);
      expect(results, [null]);
    });

    // 서버는 이 넷 중 셋을 같은 409 로 준다(남의 선점만 403). 상태 코드로는 못
    // 가르므로 예외 이름을 본다. 서버 문구를 그대로 띄우면 `(seatId=1009)` 같은
    // 디버깅용 꼬리까지 사용자에게 보인다.
    final rejections =
        <({String reason, ApiException failure, String expected})>[
          (
            reason: '잡아 둔 시간이 지났을 때',
            failure: const ApiException(
              '선점 상태가 아닌 좌석입니다. (seatId=1009)',
              status: 409,
              exceptionName: BookingServerErrors.seatNotHeld,
            ),
            expected: PaymentConstants.holdExpired,
          ),
          (
            reason: '남이 잡고 있는 자리일 때',
            failure: const ApiException(
              '본인이 선점한 좌석이 아닙니다. (seatId=1009)',
              status: 403,
              exceptionName: BookingServerErrors.seatHoldNotOwned,
            ),
            expected: PaymentConstants.holdNotOwned,
          ),
          (
            reason: '이 공연 티켓이 이미 있을 때',
            failure: const ApiException(
              '이미 이 공연의 티켓을 보유하고 있습니다. (concertId=3)',
              status: 409,
              exceptionName: BookingServerErrors.alreadyReserved,
            ),
            expected: PaymentConstants.alreadyReserved,
          ),
          (
            reason: '예매 중인 공연이 아닐 때',
            failure: const ApiException(
              '예매 중인 공연이 아닙니다. (concertId=3, status=CLOSED)',
              status: 409,
              exceptionName: BookingServerErrors.concertNotOnSale,
            ),
            expected: PaymentConstants.concertNotOnSale,
          ),
        ];

    for (final rejection in rejections) {
      testWidgets('${rejection.reason} 우리 문구로 알린다', (tester) async {
        await _pumpFlow(tester, api: api, booking: booking, results: results);
        api.failure = rejection.failure;

        await pay(tester);

        expect(find.text(rejection.expected), findsOneWidget);
        // 서버 문구의 디버깅용 꼬리가 새어 나오지 않는다.
        expect(find.textContaining('='), findsNothing);
        expect(find.byType(PaymentScreen), findsNothing);
        expect(results, [null]);
      });
    }

    testWidgets('로그인이 풀려 있으면 로그인 안내와 함께 돌아간다', (tester) async {
      await _pumpFlow(tester, api: api, booking: booking, results: results);
      api.failure = const ApiException('인증 정보가 올바르지 않습니다.', status: 401);

      await pay(tester);

      expect(find.text(PaymentConstants.loginRequired), findsOneWidget);
      expect(find.byType(PaymentScreen), findsNothing);
    });

    // 자리는 아직 잡혀 있다. 화면에 남겨 다시 누를 수 있게 한다.
    testWidgets('인터넷이 끊기면 결제 화면에 남아 다시 시도할 수 있다', (tester) async {
      await _pumpFlow(tester, api: api, booking: booking, results: results);
      api.failure = const ApiException('인터넷 연결을 확인해주세요.');

      await pay(tester);

      expect(find.text('인터넷 연결을 확인해주세요.'), findsOneWidget);
      expect(find.byType(PaymentScreen), findsOneWidget);
      expect(results, isEmpty);

      // 다시 누르면 요청이 다시 나간다.
      api.failure = null;
      await pay(tester);

      expect(api.created, hasLength(1));
      expect(find.byType(PaymentCompleteScreen), findsOneWidget);
    });
  });

  group('발행 상태', () {
    late _FakeTicketApi api;

    setUp(() => api = _FakeTicketApi());

    final issuing = _FakeTicketApi.detail();
    final issued = _FakeTicketApi.detail(tokenId: '42');
    final failed = _FakeTicketApi.detail(
      status: ReservationStatus.cancelled,
      failureReason: 'insufficient balance',
    );

    /// 완료 화면을 1초마다 묻고 3초에 그만두는 설정으로 띄운다.
    Future<void> pumpComplete(WidgetTester tester, {int? reservationId}) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        TicketApiScope(
          api: api,
          child: MaterialApp(
            home: PaymentCompleteScreen(
              order: PaymentConstants.sampleOrder,
              reservationId: reservationId,
              pollInterval: const Duration(seconds: 1),
              pollTimeout: const Duration(seconds: 3),
            ),
          ),
        ),
      );
    }

    testWidgets('발행이 끝나면 배지가 완료로 바뀌고 더 묻지 않는다', (tester) async {
      api.pollResponses.addAll([issuing, issued]);
      await pumpComplete(tester, reservationId: 7);
      // 기다리는 동안에는 연출만 돈다. 예약 정보도 버튼도 아직 없다.
      expect(find.text(PaymentConstants.issuingCeremonyTitle), findsOneWidget);
      expect(find.text(PaymentConstants.seatLabel), findsNothing);
      expect(find.text(PaymentConstants.viewTicketLabel), findsNothing);
      expect(find.text(PaymentConstants.goHomeLabel), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      expect(api.polls, 1);
      expect(find.text(PaymentConstants.issuingCeremonyTitle), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      // 끝난 상태는 배지가 아니라 마스코트가 알린다.
      expect(find.text(PaymentConstants.issuedBadgeLabel), findsNothing);
      expect(find.byType(TimoMascot), findsOneWidget);
      expect(find.text(PaymentConstants.issuedDescription), findsOneWidget);
      // 발행이 잘 끝났으면 결제가 끝났다는 제목이 그대로 유효하다.
      expect(find.text(PaymentConstants.completeTitle), findsOneWidget);
      // 돈이 나간 것이 맞으므로 카드도 '결제 금액' 그대로다.
      expect(find.text(PaymentConstants.paidAmountLabel), findsOneWidget);
      // 티켓이 생겨야 보러 갈 곳이 생긴다. 그때 버튼이 올라온다.
      expect(find.text(PaymentConstants.viewTicketLabel), findsOneWidget);
      expect(find.text(PaymentConstants.goHomeLabel), findsOneWidget);

      // 끝난 뒤에는 서버를 더 두드리지 않는다.
      await tester.pump(const Duration(seconds: 3));
      expect(api.polls, 2);
    });

    testWidgets('발행이 실패하면 실패 배지와 환불 안내가 나온다', (tester) async {
      api.pollResponses.add(failed);
      await pumpComplete(tester, reservationId: 7);

      await tester.pump(const Duration(seconds: 1));

      expect(find.text(PaymentConstants.issueFailedBadgeLabel), findsNothing);
      expect(find.byType(TimoMascot), findsOneWidget);
      expect(
        find.text(PaymentConstants.issueFailedDescription),
        findsOneWidget,
      );
      // 제목까지 바꾼다. '결제가 완료됐어요' 가 남으면 환불 안내와 부딪힌다.
      expect(find.text(PaymentConstants.issueFailedTitle), findsOneWidget);
      expect(find.text(PaymentConstants.completeTitle), findsNothing);
      // 카드 마지막 줄도 바뀐다. '결제 금액' 이 남으면 바로 위 환불 안내와
      // 정반대로 읽힌다.
      expect(find.text(PaymentConstants.refundAmountLabel), findsOneWidget);
      expect(find.text(PaymentConstants.paidAmountLabel), findsNothing);
      // 발행이 엎어져 티켓이 없다. 보러 가라고 하면 빈 목록으로 보내는 셈이다.
      expect(find.text(PaymentConstants.viewTicketLabel), findsNothing);
      expect(find.text(PaymentConstants.goHomeLabel), findsOneWidget);
    });

    // 인터넷이 잠깐 끊긴 것을 발행 실패로 그리면 거짓말이다. 서버에서는 발행이
    // 그대로 진행되고 있다.
    testWidgets('한 번 못 물어도 다음 주기에 다시 묻는다', (tester) async {
      api.pollResponses.addAll([const ApiException('인터넷 연결을 확인해주세요.'), issued]);
      await pumpComplete(tester, reservationId: 7);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text(PaymentConstants.issuingCeremonyTitle), findsOneWidget);
      expect(find.text(PaymentConstants.issueFailedBadgeLabel), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text(PaymentConstants.issuedDescription), findsOneWidget);
    });

    // 여기서도 연출만 계속 돌리면 누를 것도 나갈 곳도 없는 화면에 갇힌다.
    testWidgets('시간이 다 되면 그만 묻고 연출을 걷어 나갈 길을 낸다', (tester) async {
      api.pollResponses.add(issuing);
      await pumpComplete(tester, reservationId: 7);

      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      expect(api.polls, 3);

      // 실패가 아니다. 연출은 그대로 두고 제목과 문구만 바꾼다 — 결과 화면으로
      // 넘기면 발행이 끝난 것처럼 읽힌다. 끝나지 않았으니 마스코트도 없다.
      expect(find.text(PaymentConstants.issuingCeremonyTitle), findsNothing);
      expect(find.text(PaymentConstants.issueDelayedTitle), findsOneWidget);
      expect(
        find.text(PaymentConstants.issueDelayedDescription),
        findsOneWidget,
      );
      expect(find.byType(TimoMascot), findsNothing);
      // 대신 여기서는 나갈 길을 낸다.
      expect(find.text(PaymentConstants.goHomeLabel), findsOneWidget);
      expect(find.text(PaymentConstants.viewTicketLabel), findsOneWidget);
    });

    // 물어본 횟수로 시간을 세면, 응답이 느려 주기를 거를 때마다 나갈 길이
    // 열리는 시점이 뒤로 밀린다. 그 시간 내내 연출에는 누를 것이 없다.
    testWidgets('응답이 느려 주기를 걸러도 제시간에 나갈 길이 열린다', (tester) async {
      // 주기(1초)보다 오래 걸리는 응답이라 중간 주기들은 그냥 넘어간다.
      api.latency = const Duration(seconds: 2);
      api.pollResponses.add(issuing);
      await pumpComplete(tester, reservationId: 7);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));

      // 물어본 횟수는 주기 수보다 적지만, 3초가 지났으니 화면은 열려 있다.
      expect(api.polls, lessThan(3));
      expect(find.text(PaymentConstants.issuingCeremonyTitle), findsNothing);
      expect(find.text(PaymentConstants.issueDelayedTitle), findsOneWidget);
      expect(find.text(PaymentConstants.goHomeLabel), findsOneWidget);
    });

    // 클립 높이는 고정인데 글자만 커지면 화면이 넘친다. 지연이면 아래에 버튼
    // 까지 서서 더 빠듯하다. 넘치면 렌더 오류가 나므로 이 테스트가 잡는다.
    for (final delayed in [false, true]) {
      testWidgets('글자를 두 배로 키운 작은 화면에서도 연출이 안 깨진다 (지연=$delayed)', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    Expanded(child: TicketIssuingView(delayed: delayed)),
                    if (delayed) const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
      });
    }

    // 예매 흐름 밖에서 열린 완료 화면이다. 서버에 만든 주문이 없으니 물을 것도
    // 없고, 기다려도 상태가 바뀌지 않으니 연출에 가두지 않는다.
    testWidgets('예매 번호가 없으면 묻지 않고 연출도 돌리지 않는다', (tester) async {
      await pumpComplete(tester);

      await tester.pump(const Duration(seconds: 3));

      expect(api.polls, 0);
      expect(find.text(PaymentConstants.issuingCeremonyTitle), findsNothing);
      expect(find.text(PaymentConstants.issuingBadgeLabel), findsOneWidget);
    });
  });
}
