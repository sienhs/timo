import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:timo/core/network/api_exception.dart';
import 'package:timo/core/widgets/async_boundary.dart';
import 'package:timo/features/notification/notification_destination.dart';
import 'package:timo/features/notification/push_notification_scope.dart';
import 'package:timo/features/notification/push_notification_service.dart';
import 'package:timo/features/ticket/constants.dart';
import 'package:timo/features/ticket/data/ticket_api.dart';
import 'package:timo/features/ticket/models/entry_pass.dart';
import 'package:timo/features/ticket/models/my_ticket.dart';
import 'package:timo/features/ticket/models/reservation_detail.dart';
import 'package:timo/features/ticket/models/ticket_acquisition.dart';
import 'package:timo/features/ticket/models/ticket_status.dart';
import 'package:timo/features/ticket/screens/entry_qr_screen.dart';
import 'package:timo/features/ticket/state/ticket_api_scope.dart';

void main() {
  final ticket = MyTicket(
    reservationId: 7,
    ticketId: 107,
    concertId: 11,
    title: '2026 REMIND: 리센느',
    venueName: '올림픽공원 체조경기장',
    sectionName: 'R석',
    seatRow: 12,
    seatNumber: 24,
    facePrice: 154000,
    status: TicketStatus.owned,
    listed: false,
    acquiredBy: TicketAcquisition.booking,
    acquiredAt: DateTime(2026, 8, 1),
    startAt: DateTime(2026, 9, 14, 19),
  );

  /// 화면이 보는 시각. [advance] 로 돌린다.
  late DateTime now;
  late _FakeEntryPassApi api;
  late _FakePush push;

  setUp(() {
    now = DateTime(2026, 9, 14, 18);
    api = _FakeEntryPassApi(() => now);
    push = _FakePush();
  });

  tearDown(() => push.dispose());

  /// 화면을 띄우고 첫 발급 응답까지 받는다.
  ///
  /// `pumpAndSettle` 은 쓰지 않는다. 매초 도는 타이머가 있어 끝나지 않는다.
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      PushNotificationScope(
        push: push,
        child: TicketApiScope(
          api: api,
          child: MaterialApp(
            home: EntryQrScreen(ticket: ticket, clock: () => now),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// 입장 푸시를 흘려보내고 화면이 받아 그릴 때까지 돌린다.
  Future<void> pushEntered(WidgetTester tester, int ticketId) async {
    push.entered(ticketId);
    await tester.pump();
  }

  /// 화면의 시계와 테스트의 시계를 함께 돌린다. 화면은 타이머로 깨어나되
  /// 남은 시간은 시계로 재므로 둘을 같이 돌려야 실제 흐름과 같아진다.
  Future<void> advance(WidgetTester tester, Duration by) async {
    now = now.add(by);
    await tester.pump(by);
  }

  /// 지금 화면에 그려진 QR 문자열. `QrImageView` 는 문자열을 밖에 안 내주므로
  /// 화면이 키로 달아 둔 값을 꺼낸다.
  String qrData(WidgetTester tester) =>
      (tester.widget<QrImageView>(find.byType(QrImageView)).key
              as ValueKey<String>)
          .value;

  /// 테스트 뷰포트는 폰보다 넓어 정사각 QR 칸이 커진다. 칸 가운데의 버튼이
  /// 화면 아래로 밀리므로 끌어 올린 뒤 누른다. 스크롤은 다음 프레임에
  /// 반영되므로 한 번 그린 뒤에 눌러야 제자리를 맞힌다.
  Future<void> tapInQrArea(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
  }

  final retryButton = find.widgetWithText(TextButton, AsyncBoundary.retryLabel);
  final refreshButton = find.byTooltip(TicketStrings.qrRefresh);

  group('화면', () {
    testWidgets('공연 정보와 QR, 안내가 함께 나온다', (tester) async {
      await pumpScreen(tester);

      expect(find.text(TicketStrings.qrScreenTitle), findsOneWidget);
      expect(find.text('2026 REMIND: 리센느'), findsOneWidget);
      expect(find.textContaining('R석 12열 24번'), findsOneWidget);
      expect(find.textContaining('올림픽공원 체조경기장'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text(TicketStrings.qrValidFor(30)), findsOneWidget);

      // 안내 상자는 QR 아래라 화면 밖이다. 끌어 올려서 본다.
      await tester.scrollUntilVisible(find.textContaining('화면을 캡처한 QR'), 200);
      expect(find.textContaining('화면을 캡처한 QR'), findsOneWidget);
    });

    // 예매 응답에 게이트 값이 없다. 없는 정보를 그럴듯하게 채우지 않는다.
    testWidgets('입장 게이트는 그리지 않는다', (tester) async {
      await pumpScreen(tester);

      expect(find.textContaining('게이트'), findsNothing);
    });

    testWidgets('하단 바를 달지 않는다', (tester) async {
      await pumpScreen(tester);

      expect(find.text('빠른 메뉴'), findsNothing);
    });
  });

  group('발급', () {
    // 예매 번호(7)가 아니라 티켓 번호(107)다. 바꿔 넘기면 서버가 404 를 낸다.
    testWidgets('들어오면 티켓 번호로 서버에 발급을 요청한다', (tester) async {
      await pumpScreen(tester);

      expect(api.issued, [107]);
    });

    testWidgets('응답이 오기 전에는 QR 자리에 로딩이 돈다', (tester) async {
      api.hold = true;
      await pumpScreen(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      // 아직 셀 것이 없다. 00:00 을 보이면 만료된 것으로 읽힌다.
      expect(find.text(TicketStrings.qrRemaining), findsNothing);
    });

    // 앱이 문자열 안을 해석하기 시작하면 서버가 형식을 바꿀 때마다 앱 배포가
    // 묶인다. 받은 그대로 그려야 한다.
    testWidgets('서버가 준 문자열을 그대로 QR 로 그린다', (tester) async {
      await pumpScreen(tester);

      expect(qrData(tester), api.lastToken);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(refreshButton, findsNothing);
    });

    // 사유(입장 시간대 밖 · 발행 전 · 양도 등록 중)는 서버만 안다.
    testWidgets('실패하면 QR 자리에 서버 문구와 다시 시도가 나온다', (tester) async {
      api.failure = const ApiException('입장 QR 을 발급할 수 없는 티켓입니다.', status: 409);
      await pumpScreen(tester);

      expect(find.text('입장 QR 을 발급할 수 없는 티켓입니다.'), findsOneWidget);
      expect(retryButton, findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text(TicketStrings.qrRemaining), findsNothing);
    });

    testWidgets('입장 완료 상태를 확인하면 이미 입장한 QR이라고 알린다', (tester) async {
      api.failure = const ApiException('입장 QR 을 발급할 수 없는 티켓입니다.', status: 409);
      api.tickets = [ticket.copyWith(status: TicketStatus.used)];
      await pumpScreen(tester);

      expect(find.text(TicketStrings.qrAlreadyUsed), findsOneWidget);
      expect(retryButton, findsNothing);
    });

    testWidgets('다시 시도를 누르면 다시 요청하고, 되면 QR 이 나온다', (tester) async {
      api.failure = const ApiException('인터넷 연결을 확인해주세요.');
      await pumpScreen(tester);

      api.failure = null;
      await tapInQrArea(tester, retryButton);

      expect(api.issued, [107, 107]);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('인터넷 연결을 확인해주세요.'), findsNothing);
    });
  });

  group('남은 시간', () {
    testWidgets('처음에는 서버가 준 수명 전부가 남아 있다', (tester) async {
      await pumpScreen(tester);

      expect(find.text('00:30'), findsOneWidget);
    });

    // 30 을 앱에 박아 두면 서버가 수명을 바꿨을 때 카운트다운과 문구가 거짓말을 한다.
    testWidgets('수명은 서버가 준 값을 따른다', (tester) async {
      api.lifetime = const Duration(seconds: 60);
      await pumpScreen(tester);

      expect(find.text('01:00'), findsOneWidget);
      expect(find.text(TicketStrings.qrValidFor(60)), findsOneWidget);
    });

    testWidgets('1초마다 남은 시간이 줄지만 QR 은 그대로다', (tester) async {
      await pumpScreen(tester);
      final first = qrData(tester);

      await advance(tester, const Duration(seconds: 1));
      expect(find.text('00:29'), findsOneWidget);
      expect(qrData(tester), first);

      await advance(tester, const Duration(seconds: 1));
      expect(find.text('00:28'), findsOneWidget);
      expect(qrData(tester), first);
      expect(api.issued, hasLength(1));
    });

    // 켜 둔 채로 두면 목록으로 돌아간 뒤에도 매초 깨어나 배터리를 먹는다.
    testWidgets('화면을 벗어나면 타이머가 멈춘다', (tester) async {
      await pumpScreen(tester);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // 타이머가 남아 있으면 이 pump 에서 setState 가 불려 예외가 난다.
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });

    // 응답이 오기 전에 나갔다. 늦게 온 응답이 사라진 화면을 그리려 하면 안 된다.
    testWidgets('응답을 기다리다 벗어나도 예외가 없다', (tester) async {
      api.hold = true;
      await pumpScreen(tester);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      api.release();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('입장 확인', () {
    final checkInterval = TicketMetrics.qrEntryCheckInterval;

    testWidgets('이 티켓의 입장 푸시가 오면 QR 대신 이미 입장했다고 알린다', (tester) async {
      await pumpScreen(tester);

      await pushEntered(tester, 107);

      expect(find.text(TicketStrings.qrAlreadyUsed), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text(TicketStrings.qrRemaining), findsNothing);
      expect(retryButton, findsNothing);
    });

    // 티켓을 여러 장 가진 사람이 동행의 표를 먼저 찍었을 수 있다.
    testWidgets('다른 티켓의 입장 푸시는 무시한다', (tester) async {
      await pumpScreen(tester);

      await pushEntered(tester, 108);

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text(TicketStrings.qrAlreadyUsed), findsNothing);
    });

    // 푸시는 빠지거나 늦을 수 있다. 앱이 뒤에 있을 때 온 푸시는 아예 못 받는다.
    testWidgets('푸시가 없어도 주기마다 확인해 입장 완료면 바뀐다', (tester) async {
      await pumpScreen(tester);

      await advance(tester, checkInterval - const Duration(seconds: 1));
      expect(api.ticketFetches, 0);

      api.tickets = [ticket.copyWith(status: TicketStatus.used)];
      await advance(tester, const Duration(seconds: 1));
      await tester.pump();

      expect(api.ticketFetches, 1);
      expect(find.text(TicketStrings.qrAlreadyUsed), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
    });

    testWidgets('아직 입장 전이면 QR 을 그대로 둔다', (tester) async {
      api.tickets = [ticket];
      await pumpScreen(tester);
      final first = qrData(tester);

      await advance(tester, checkInterval);
      await tester.pump();

      expect(api.ticketFetches, 1);
      expect(qrData(tester), first);
    });

    // 검표 줄에서 오류 문구가 튀어나오면 안 된다. 다음 차례에 다시 묻는다.
    testWidgets('확인이 실패해도 QR 은 그대로고 다음 차례에 다시 묻는다', (tester) async {
      await pumpScreen(tester);
      final first = qrData(tester);

      api.ticketsFailure = const ApiException('인터넷 연결을 확인해주세요.');
      await advance(tester, checkInterval);
      await tester.pump();

      expect(qrData(tester), first);
      expect(find.text('인터넷 연결을 확인해주세요.'), findsNothing);

      api.ticketsFailure = null;
      await advance(tester, checkInterval);
      await tester.pump();

      expect(api.ticketFetches, 2);
    });

    testWidgets('입장 완료 뒤에는 더 확인하지 않는다', (tester) async {
      await pumpScreen(tester);
      await pushEntered(tester, 107);

      await advance(tester, checkInterval * 3);

      expect(api.ticketFetches, 0);
    });

    // 새로고침을 누르고 기다리는 사이 게이트에서 찍혔다. 늦게 온 새 QR 이 입장
    // 완료 안내를 덮으면 이미 쓴 표가 다시 살아난 것처럼 보인다.
    testWidgets('새로 받는 중에 입장 푸시가 오면 늦은 응답이 QR 로 덮지 않는다', (tester) async {
      await pumpScreen(tester);
      await advance(tester, const Duration(seconds: 30));
      api.hold = true;
      await tapInQrArea(tester, refreshButton);

      await pushEntered(tester, 107);
      api.release();
      await tester.pump();

      expect(find.text(TicketStrings.qrAlreadyUsed), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      expect(retryButton, findsNothing);
    });

    // 새로고침이 실패하면 QR 자리에 안내만 남는다. 찍힐 QR 이 없으니 물을 것도 없다.
    testWidgets('새로고침 실패 안내가 떠 있으면 확인하지 않는다', (tester) async {
      await pumpScreen(tester);
      await advance(tester, const Duration(seconds: 30));
      api.failure = const ApiException('인터넷 연결을 확인해주세요.');
      await tapInQrArea(tester, refreshButton);
      final fetchesBefore = api.ticketFetches;

      await advance(tester, checkInterval * 2);

      expect(api.ticketFetches, fetchesBefore);
    });

    testWidgets('화면을 벗어난 뒤 온 입장 푸시는 예외 없이 지나간다', (tester) async {
      await pumpScreen(tester);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      await pushEntered(tester, 107);
      expect(tester.takeException(), isNull);
    });
  });

  group('만료·새로고침', () {
    // 자동으로 새로 받지 않는다. 줄을 서는 동안 30초마다 요청이 나가고,
    // 검표 직전에 QR 이 바뀌는 순간이 생기기 때문이다.
    testWidgets('수명이 다하면 QR 은 남고 새로고침 버튼이 나온다, 서버는 안 부른다', (tester) async {
      await pumpScreen(tester);
      final first = qrData(tester);

      await advance(tester, const Duration(seconds: 30));

      expect(qrData(tester), first);
      expect(refreshButton, findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text(TicketStrings.qrExpiredNotice), findsOneWidget);
      expect(find.text(TicketStrings.qrValidFor(30)), findsNothing);
      expect(api.issued, hasLength(1));
    });

    testWidgets('만료된 채로 두어도 매초 서버를 두드리지 않는다', (tester) async {
      await pumpScreen(tester);

      await advance(tester, const Duration(seconds: 30));
      await advance(tester, const Duration(seconds: 3));

      expect(api.issued, hasLength(1));
      expect(refreshButton, findsOneWidget);
    });

    testWidgets('새로고침을 누르면 새 QR 을 받고 남은 시간이 다시 찬다', (tester) async {
      await pumpScreen(tester);
      final first = qrData(tester);
      await advance(tester, const Duration(seconds: 30));

      await tapInQrArea(tester, refreshButton);

      expect(api.issued, [107, 107]);
      expect(qrData(tester), isNot(first));
      expect(find.text('00:30'), findsOneWidget);
      expect(refreshButton, findsNothing);
      expect(find.text(TicketStrings.qrValidFor(30)), findsOneWidget);
    });

    // 앱이 백그라운드에 있는 동안 타이머는 멈춰도 시간은 흐른다. 돌아왔을 때
    // 지난 QR 을 "몇 초 남음" 으로 보여주면 입장 줄에서 안 통한다.
    testWidgets('한참 뒤에 돌아오면 바로 만료 상태다', (tester) async {
      await pumpScreen(tester);

      await advance(tester, const Duration(minutes: 10));

      expect(refreshButton, findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
    });

    // QR 자리가 하얗게 비었다 채워지면 화면이 깜빡인다. 흐린 QR 위에 로딩만 돈다.
    testWidgets('새로 받는 동안 이전 QR 위에 로딩이 돈다', (tester) async {
      await pumpScreen(tester);
      final first = qrData(tester);
      await advance(tester, const Duration(seconds: 30));

      api.hold = true;
      await tapInQrArea(tester, refreshButton);

      expect(qrData(tester), first);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(refreshButton, findsNothing);

      api.release();
      await tester.pump();

      expect(qrData(tester), isNot(first));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('새로 받다가 실패하면 문구와 다시 시도가 나온다', (tester) async {
      await pumpScreen(tester);
      await advance(tester, const Duration(seconds: 30));

      api.failure = const ApiException('인터넷 연결을 확인해주세요.');
      await tapInQrArea(tester, refreshButton);

      expect(find.text('인터넷 연결을 확인해주세요.'), findsOneWidget);
      expect(retryButton, findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
    });
  });
}

/// 입장 QR 발급만 흉내 내는 가짜 API. 요청을 기록하고, 실패·지연을 꾸민다.
/// 이 화면은 발급 하나만 부르므로 나머지는 불리면 안 된다.
class _FakeEntryPassApi implements TicketApi {
  _FakeEntryPassApi(this.clock);

  /// 받은 시각을 찍는 시계. 화면과 같은 것을 받아야 남은 시간이 맞는다.
  final DateTime Function() clock;

  /// 서버가 정한 수명. 응답에 실려 나간다.
  Duration lifetime = const Duration(seconds: 30);

  /// 넣어 두면 다음 요청부터 이걸 던진다.
  ApiException? failure;

  /// 켜 두면 응답을 [release] 할 때까지 붙들어 둔다.
  bool hold = false;

  /// 요청받은 티켓 번호. 순서대로.
  final issued = <int>[];

  /// 마지막으로 내준(또는 붙들어 둔) 문자열.
  String lastToken = '';

  Completer<EntryPass>? _held;
  EntryPass? _heldPass;

  /// 부를 때마다 다른 문자열이 나가게 하는 번호. 실제 서버도 만료 시각이
  /// 매번 달라 문자열이 다르다.
  int _serial = 0;

  @override
  Future<EntryPass> issueEntryPass(int ticketId) async {
    issued.add(ticketId);
    if (failure case final failure?) throw failure;

    lastToken = 'timo:entry:1:$ticketId.${_serial++}.fakeSignature';
    final pass = EntryPass(
      token: lastToken,
      lifetime: lifetime,
      receivedAt: clock(),
    );
    if (!hold) return pass;

    _heldPass = pass;
    return (_held = Completer<EntryPass>()).future;
  }

  /// 붙들어 둔 응답을 내보낸다. 받은 시각은 내보내는 지금으로 다시 찍는다 —
  /// 실제로도 응답이 도착한 순간이 기준이다.
  void release() {
    final held = _held;
    final pass = _heldPass;
    if (held == null || pass == null) return;
    _held = null;
    _heldPass = null;
    held.complete(
      EntryPass(
        token: pass.token,
        lifetime: pass.lifetime,
        receivedAt: clock(),
      ),
    );
  }

  List<MyTicket> tickets = [];

  /// 넣어 두면 목록 조회가 이걸 던진다.
  ApiException? ticketsFailure;

  /// 목록 조회 횟수. 입장 확인이 몇 번 나갔는지 본다.
  int ticketFetches = 0;

  @override
  Future<List<MyTicket>> fetchMyTickets() async {
    ticketFetches++;
    if (ticketsFailure case final failure?) throw failure;
    return tickets;
  }

  @override
  Future<void> cancelReservation(int reservationId) =>
      throw UnimplementedError('입장 QR 화면은 예매를 취소하지 않는다');

  @override
  Future<ReservationDetail> createReservation({
    required int concertId,
    required int seatId,
  }) => throw UnimplementedError('입장 QR 화면은 주문을 만들지 않는다');

  @override
  Future<ReservationDetail> fetchReservation(int reservationId) =>
      throw UnimplementedError('입장 QR 화면은 주문 상세를 부르지 않는다');
}

/// 입장 푸시만 흘려보내는 가짜 푸시. 나머지는 이 화면이 쓰지 않는다.
class _FakePush implements PushNotifications {
  final _enteredTicketIds = StreamController<int>.broadcast();

  void entered(int ticketId) => _enteredTicketIds.add(ticketId);

  Future<void> dispose() => _enteredTicketIds.close();

  @override
  Stream<int> get enteredTicketIds => _enteredTicketIds.stream;

  @override
  Stream<int> get unreadCounts => const Stream.empty();

  @override
  NotificationDestination? takeLaunchDestination() => null;

  @override
  Future<void> registerDevice() async {}

  @override
  Future<void> unregisterDevice() async {}
}
