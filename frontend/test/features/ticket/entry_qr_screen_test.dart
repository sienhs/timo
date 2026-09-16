import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:timo/features/ticket/constants.dart';
import 'package:timo/features/ticket/models/entry_pass.dart';
import 'package:timo/features/ticket/models/my_ticket.dart';
import 'package:timo/features/ticket/models/ticket_status.dart';
import 'package:timo/features/ticket/screens/entry_qr_screen.dart';

void main() {
  final ticket = MyTicket(
    reservationId: 7,
    concertId: 11,
    title: '2026 REMIND: 리센느',
    venueName: '올림픽공원 체조경기장',
    sectionName: 'R석',
    seatRow: 12,
    seatNumber: 24,
    facePrice: 154000,
    status: TicketStatus.paid,
    bookedAt: DateTime(2026, 8, 1),
    startAt: DateTime(2026, 9, 14, 19),
  );

  /// 화면이 보는 시각. [advance] 로 돌린다.
  late DateTime now;

  setUp(() => now = DateTime(2026, 9, 14, 18));

  Future<void> pumpScreen(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: EntryQrScreen(ticket: ticket, clock: () => now),
    ),
  );

  /// 화면의 시계와 테스트의 시계를 함께 돌린다.
  ///
  /// 화면은 타이머로 깨어나되 남은 시간은 시계로 잰다(백그라운드에서 타이머가
  /// 멈춰도 시간은 흐르므로). 둘을 같이 돌려야 실제 흐름과 같아진다.
  Future<void> advance(WidgetTester tester, Duration by) async {
    now = now.add(by);
    await tester.pump(by);
  }

  /// 지금 화면에 그려진 QR 문자열.
  ///
  /// `QrImageView` 는 그릴 문자열을 private 으로 들고 있어 밖에서 읽을 수 없다.
  /// 화면이 그 값을 키로 달아 두므로 키에서 꺼낸다.
  String qrData(WidgetTester tester) =>
      (tester.widget<QrImageView>(find.byType(QrImageView)).key
              as ValueKey<String>)
          .value;

  group('화면', () {
    testWidgets('공연 정보와 QR, 안내가 함께 나온다', (tester) async {
      await pumpScreen(tester);

      expect(find.text(TicketStrings.qrScreenTitle), findsOneWidget);
      expect(find.text('2026 REMIND: 리센느'), findsOneWidget);
      expect(find.textContaining('R석 12열 24번'), findsOneWidget);
      expect(find.textContaining('올림픽공원 체조경기장'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text(TicketStrings.qrRotateNotice), findsOneWidget);

      // 안내 상자는 QR 아래라 화면 밖이다. 끌어 올려서 본다.
      await tester.scrollUntilVisible(find.textContaining('화면을 캡처한 QR'), 200);
      expect(find.textContaining('화면을 캡처한 QR'), findsOneWidget);
    });

    // 시안에 '입장 게이트: GATE1' 이 있지만 뺐다. 예매 응답에 그 값이 없고,
    // 없는 정보를 그럴듯하게 채우면 실제 게이트와 다를 때 입장에서 문제가 된다.
    testWidgets('입장 게이트는 그리지 않는다', (tester) async {
      await pumpScreen(tester);

      expect(find.textContaining('게이트'), findsNothing);
    });

    testWidgets('하단 바를 달지 않는다', (tester) async {
      await pumpScreen(tester);

      expect(find.text('빠른 메뉴'), findsNothing);
    });
  });

  group('30초 회전', () {
    testWidgets('처음에는 30초가 남아 있다', (tester) async {
      await pumpScreen(tester);

      expect(find.text('00:30'), findsOneWidget);
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
    });

    testWidgets('30초가 지나면 QR 이 새로 만들어진다', (tester) async {
      await pumpScreen(tester);
      final first = qrData(tester);

      await advance(tester, const Duration(seconds: 30));

      expect(qrData(tester), isNot(first));
      expect(find.text('00:30'), findsOneWidget);
    });

    // 앱이 백그라운드에 있는 동안 타이머는 멈춰도 시간은 흐른다. 돌아왔을 때
    // 지난 QR 을 "몇 초 남음" 으로 보여주면 입장 줄에서 안 통한다.
    testWidgets('한참 뒤에 돌아와도 QR 이 새로 만들어진다', (tester) async {
      await pumpScreen(tester);
      final first = qrData(tester);

      await advance(tester, const Duration(minutes: 10));

      expect(qrData(tester), isNot(first));
      expect(find.text('00:30'), findsOneWidget);
    });

    testWidgets('QR 에 예매 id 가 실린다', (tester) async {
      await pumpScreen(tester);

      expect(qrData(tester), startsWith('timo:entry:7:'));
    });

    // 켜 둔 채로 두면 목록으로 돌아간 뒤에도 매초 깨어나 배터리를 먹는다.
    testWidgets('화면을 벗어나면 타이머가 멈춘다', (tester) async {
      await pumpScreen(tester);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // 타이머가 남아 있으면 이 pump 에서 setState 가 불려 예외가 난다.
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });
  });

  group('EntryPass', () {
    test('발급 직후에는 수명 전부가 남는다', () {
      final now = DateTime(2026, 9, 14, 19);
      final pass = EntryPass.issue(reservationId: 1, now: now);

      expect(pass.remaining(now), EntryPass.lifetime);
      expect(pass.progress(now), 1.0);
    });

    test('시간이 지나면 남은 시간이 준다', () {
      final now = DateTime(2026, 9, 14, 19);
      final pass = EntryPass.issue(reservationId: 1, now: now);

      final later = now.add(const Duration(seconds: 20));
      expect(pass.remaining(later), const Duration(seconds: 10));
    });

    test('수명이 다 지나면 0 이고 음수로 내려가지 않는다', () {
      final now = DateTime(2026, 9, 14, 19);
      final pass = EntryPass.issue(reservationId: 1, now: now);

      final later = now.add(const Duration(minutes: 5));
      expect(pass.remaining(later), Duration.zero);
      expect(pass.progress(later), 0.0);
    });

    // 규칙만 알면 누구나 만들 수 있는 값이라 위조를 막지 못한다. 서버가 서명한
    // 토큰으로 바뀌기 전까지는 같은 예매라도 발급할 때마다 값이 달라야 한다.
    test('같은 예매라도 발급할 때마다 값이 다르다', () {
      final now = DateTime(2026, 9, 14, 19);
      final a = EntryPass.issue(reservationId: 1, now: now);
      final b = EntryPass.issue(reservationId: 1, now: now);

      expect(a.payload, isNot(b.payload));
    });
  });
}
