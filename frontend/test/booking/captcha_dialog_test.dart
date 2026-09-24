import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/network/api_exception.dart';
import 'package:timo/core/theme/app_theme.dart';
import 'package:timo/features/booking/constants.dart';
import 'package:timo/features/booking/data/booking_api.dart';
import 'package:timo/features/booking/data/mock_booking_api.dart';
import 'package:timo/features/booking/models/captcha_challenge.dart';
import 'package:timo/features/booking/state/booking_api_scope.dart';
import 'package:timo/features/booking/widgets/captcha_dialog.dart';

/// 문제를 한 번도 못 받는 API. 네이버 장애(502)를 흉내 낸다. 문구는 실제 서버 문구다.
class _BrokenCaptchaApi extends MockBookingApi {
  _BrokenCaptchaApi() : super(latency: Duration.zero);

  @override
  Future<CaptchaChallenge> issueCaptcha() async =>
      throw const ApiException('캡차 서비스를 이용할 수 없습니다.', status: 502);
}

void main() {
  /// 창이 닫히며 돌려준 값. 아직 안 닫혔으면 null 이다.
  bool? result;

  setUp(() => result = null);

  /// 버튼 하나짜리 화면에서 보안문자 창을 띄운다.
  Future<void> openCaptcha(WidgetTester tester, BookingApi api) async {
    // 창은 home 이 아니라 Navigator 밑에 붙으므로, 앱처럼 MaterialApp 바깥을
    // 감싸야 창이 API 를 찾는다.
    await tester.pumpWidget(
      BookingApiScope(
        api: api,
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    result = await showCaptchaDialog(context, concertId: 7),
                child: const Text('구역 화면'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('구역 화면'));
    await tester.pumpAndSettle();
  }

  Finder captchaImage(String key) => find.byKey(ValueKey(key));

  FilledButton submitButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton));

  Future<void> submit(WidgetTester tester, String value) async {
    await tester.enterText(find.byType(TextField), value);
    // 입력 직후엔 확인 버튼이 아직 잠겨 있다. 한 번 다시 그려야 풀린다.
    await tester.pump();
    await tester.tap(find.text(BookingStrings.captchaSubmit));
    await tester.pumpAndSettle();
  }

  testWidgets('그림을 받아 보여 주고, 입력 전에는 확인이 잠겨 있다', (tester) async {
    await openCaptcha(tester, MockBookingApi(latency: Duration.zero));

    expect(find.text(BookingStrings.captchaTitle), findsOneWidget);
    expect(captchaImage('mock-captcha-1'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'a');
    await tester.pump();
    expect(submitButton(tester).onPressed, isNotNull);
  });

  testWidgets('맞게 입력하면 통과로 닫힌다', (tester) async {
    await openCaptcha(tester, MockBookingApi(latency: Duration.zero));

    await submit(tester, 'TIMO');

    expect(result, isTrue);
    expect(find.text(BookingStrings.captchaTitle), findsNothing);
  });

  testWidgets('틀리면 사유를 보여 주고 입력칸을 비운 뒤 새 그림으로 바꾼다', (tester) async {
    await openCaptcha(tester, MockBookingApi(latency: Duration.zero));

    await submit(tester, 'wrong');

    expect(result, isNull);
    expect(find.text(BookingStrings.captchaMismatch), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    // 한 번 쓴 키는 폐기됐으니 새 문제여야 한다.
    expect(captchaImage('mock-captcha-1'), findsNothing);
    expect(captchaImage('mock-captcha-2'), findsOneWidget);

    // 새 그림으로 다시 풀면 통과한다.
    await submit(tester, 'timo');
    expect(result, isTrue);
  });

  testWidgets('새로고침하면 새 그림을 받고 이전 사유를 지운다', (tester) async {
    await openCaptcha(tester, MockBookingApi(latency: Duration.zero));
    await submit(tester, 'wrong');

    await tester.tap(find.byTooltip(BookingStrings.captchaRefresh));
    await tester.pumpAndSettle();

    expect(captchaImage('mock-captcha-3'), findsOneWidget);
    expect(find.text(BookingStrings.captchaMismatch), findsNothing);
  });

  testWidgets('문제를 못 받으면 앱 문구로 알리고 확인은 잠겨 있다', (tester) async {
    await openCaptcha(tester, _BrokenCaptchaApi());

    // 서버 문구('캡차 …')가 아니라 앱 문구를 보여 준다.
    expect(find.text(BookingStrings.captchaUnavailable), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'timo');
    await tester.pump();
    expect(submitButton(tester).onPressed, isNull);
  });

  testWidgets('창 바깥을 눌러도 닫히지 않는다', (tester) async {
    await openCaptcha(tester, MockBookingApi(latency: Duration.zero));

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text(BookingStrings.captchaTitle), findsOneWidget);
  });

  testWidgets('닫기를 누르면 통과하지 않은 것으로 닫힌다', (tester) async {
    await openCaptcha(tester, MockBookingApi(latency: Duration.zero));

    await tester.tap(find.byTooltip(BookingStrings.captchaClose));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets('뒤로 가기도 통과하지 않은 것으로 닫힌다', (tester) async {
    await openCaptcha(tester, MockBookingApi(latency: Duration.zero));

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });
}
