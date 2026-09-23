import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/app.dart';
import 'package:timo/core/widgets/error_snack_bar.dart';
import 'package:timo/features/auth/data/token_storage.dart';
import 'package:timo/features/auth/models/auth_tokens.dart';
import 'package:timo/features/auth/state/auth_session.dart';
import 'package:timo/features/booking/data/mock_booking_api.dart';
import 'package:timo/features/home/data/mock_home_api.dart';
import 'package:timo/features/show/data/mock_show_api.dart';
import 'package:timo/features/home/widgets/show_poster_card.dart';
import 'package:timo/routes/app_routes.dart';

/// 레이아웃 스모크 테스트.
///
/// 시안을 옮기는 작업에서 가장 흔한 사고는 실제 폰 폭에서 Row/Column 이
/// 넘치는 것인데, analyze 로는 잡히지 않는다. 오버플로는 테스트에서
/// FlutterError 로 터지므로 화면을 한 번 훑는 것만으로 방어가 된다.
void main() {
  /// 360 x 800 dp
  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// 예매 흐름을 띄운다.
  ///
  /// 로그인 상태로 시작한다. 예매 진입(상세의 '예매하러 가기')이 로그인을
  /// 요구해서, 로그아웃 상태로 두면 좌석 화면 대신 로그인 화면이 열린다.
  Future<void> pumpApp(WidgetTester tester) async {
    usePhoneSize(tester);
    final session = AuthSession(storage: InMemoryTokenStorage());
    await session.signIn(
      const AuthTokens(
        memberId: 1,
        accessToken: 'test-access-token',
        refreshToken: 'test-refresh-token',
        accessTokenExpiresIn: Duration(minutes: 30),
      ),
    );
    addTearDown(session.dispose);

    await tester.pumpWidget(
      App(
        // 로딩 화면을 건너뛰고 홈에서 시작한다.
        initialRoute: AppRoutes.home,
        session: session,
        homeApi: const MockHomeApi(latency: Duration.zero),
        // 예매 화면은 서버에서 구역·좌석을 받아 온다. 테스트에서는 고정
        // 배치도를 주는 목을 꽂아야 배치도가 그려진다.
        bookingApi: MockBookingApi(latency: Duration.zero),
        // 공연 상세도 서버에서 받아 온다. 예매로 들어가려면 상세를 거쳐야 해서
        // 여기에도 목이 필요하다.
        showApi: const MockShowApi(latency: Duration.zero),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 홈에서 예매 흐름으로 들어간다.
  ///
  /// 홈 -> 공연 상세 -> 좌석 선택 순이다. 예매 진입은 상세가 맡으므로 홈에서
  /// 좌석 선택으로 바로 갈 수는 없다.
  ///
  /// 이미 오픈한 공연(아이유)을 고른다. 오픈 전 공연은 상세에 '오픈 알림 받기'
  /// 만 있어 예매로 들어갈 수 없다.
  Future<void> enterBookingFromHome(WidgetTester tester) async {
    final card = find.widgetWithText(ShowPosterCard, '2026 아이유 콘서트');
    // 인기 공연 줄은 첫 화면 아래에 있다. 세로 목록(맨 바깥 스크롤)을 끌어
    // 올려야 카드가 만들어진다.
    await tester.scrollUntilVisible(
      card,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // 스크롤은 카드가 '보이기 시작하면' 멈춘다. 배너가 커지면서 카드가 화면
    // 끝에 걸친 채로 멈추는 일이 생겨, 누를 수 있는 자리까지 마저 올린다.
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
    await tester.tap(find.text('예매하러 가기'));
    await tester.pumpAndSettle();
  }

  testWidgets('폰 크기에서 예매 흐름 화면이 오버플로 없이 그려진다', (tester) async {
    await pumpApp(tester);

    // 앱은 하단 바를 두른 홈 셸에서 시작한다. 예매 흐름은 홈에서 들어간다.
    await enterBookingFromHome(tester);

    expect(find.text('STAGE'), findsOneWidget);
    expect(find.text('* 1인 1매만 예매할 수 있어요'), findsOneWidget);

    // 잔여좌석보기 패널: 매진 구역이 0석으로 찍힌다
    await tester.tap(find.text('잔여좌석보기'));
    await tester.pumpAndSettle();
    expect(find.text('매진'), findsOneWidget);

    // 좌석가격보기 패널: 요구사항상 모든 구역이 동일 금액
    await tester.tap(find.text('좌석가격보기'));
    await tester.pumpAndSettle();
    expect(find.text('186,000원'), findsNWidgets(5));

    // 패널을 닫고 구역 상세로 진입
    await tester.tap(find.text('좌석가격보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('FLOOR A'));
    await tester.pumpAndSettle();

    // 셀이 44px 로 커지면서 열 라벨은 구역명 없이 번호만 둔다.
    expect(find.text('1열'), findsOneWidget);
    // 시안 범례 3종. '선점중' 은 노출하지 않는다.
    expect(find.text('예매가능'), findsOneWidget);
    expect(find.text('선택됨'), findsOneWidget);
    expect(find.text('선택불가'), findsOneWidget);
    expect(find.text('선점중'), findsNothing);
    expect(find.text('좌석을 선택해주세요'), findsOneWidget);
  });

  testWidgets('매진 구역을 누르면 안내만 뜨고 진입하지 않는다', (tester) async {
    await pumpApp(tester);

    // 앱은 하단 바를 두른 홈 셸에서 시작한다. 예매 흐름은 홈에서 들어간다.
    await enterBookingFromHome(tester);

    await tester.tap(find.text('FLOOR B'));
    await tester.pumpAndSettle();

    expect(
      find.text(toastText('FLOOR B 구역은 매진됐어요. 다른 구역을 골라주세요.')),
      findsOneWidget,
    );
    expect(find.text('STAGE'), findsOneWidget); // 여전히 배치도 화면
  });
}
