import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/app.dart';

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

  testWidgets('폰 크기에서 예매 흐름 화면이 오버플로 없이 그려진다', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    // 홈이 준비되기 전이라 구역 배치도에서 시작한다.
    expect(find.text('STAGE'), findsOneWidget);
    expect(find.text('* 1인 1매만 예매할 수 있어요'), findsOneWidget);

    // 잔여좌석보기 패널: 매진 구역이 0석으로 찍힌다
    await tester.tap(find.text('잔여좌석보기'));
    await tester.pumpAndSettle();
    expect(find.text('0석'), findsOneWidget);

    // 좌석가격보기 패널: 요구사항상 모든 구역이 동일 금액
    await tester.tap(find.text('좌석가격보기'));
    await tester.pumpAndSettle();
    expect(find.text('186,000원'), findsNWidgets(3));

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
    expect(find.text('예매완료'), findsOneWidget);
    expect(find.text('선점중'), findsNothing);
    expect(find.text('좌석을 선택해주세요'), findsOneWidget);
  });

  testWidgets('매진 구역을 누르면 안내만 뜨고 진입하지 않는다', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    await tester.tap(find.text('FLOOR B'));
    await tester.pumpAndSettle();

    expect(find.text('FLOOR B 구역은 매진됐어요. 다른 구역을 골라주세요.'), findsOneWidget);
    expect(find.text('STAGE'), findsOneWidget); // 여전히 배치도 화면
  });
}
