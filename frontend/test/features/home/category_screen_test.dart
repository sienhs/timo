import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/app.dart';
import 'package:timo/features/home/constants.dart';
import 'package:timo/features/home/data/mock_home_api.dart';
import 'package:timo/features/home/models/show_category.dart';
import 'package:timo/features/home/screens/all_shows_screen.dart';
import 'package:timo/routes/app_routes.dart';

/// 카테고리 화면. 빠른 메뉴에서 들어가 무엇이 보이는가와 누르면 어디로
/// 가는가만 본다. 픽셀 값은 굳히지 않는다.
void main() {
  /// 360 x 800 dp
  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpCategories(WidgetTester tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      App(
        initialRoute: AppRoutes.categories,
        // 콘서트를 누르면 공연 전체 조회가 열린다. 목을 안 꽂으면 진짜 서버로 간다.
        homeApi: const MockHomeApi(latency: Duration.zero),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('장르는 서버 순서이고 공연이 있는 것은 콘서트 하나다', () {
    expect(showCategories.map((category) => category.label).toList(), [
      '콘서트',
      '뮤지컬',
      '연극',
      '클래식',
      '페스티벌',
      '스포츠',
    ]);
    expect(
      showCategories
          .where((category) => category.isAvailable)
          .map((category) => category.label),
      ['콘서트'],
    );
  });

  testWidgets('장르 여섯이 다 보이고 공연이 없는 다섯에 준비 중 뱃지가 붙는다', (tester) async {
    await pumpCategories(tester);

    expect(find.text(HomeStrings.categoryTitle), findsOneWidget);
    for (final category in showCategories) {
      expect(find.text(category.label), findsOneWidget, reason: category.label);
    }
    expect(find.text(HomeStrings.categoryNotReadyBadge), findsNWidgets(5));
    expect(find.text(HomeStrings.categoryNote), findsOneWidget);
  });

  testWidgets('콘서트를 누르면 공연 전체 조회로 간다', (tester) async {
    await pumpCategories(tester);

    await tester.tap(find.text('콘서트'));
    await tester.pumpAndSettle();

    expect(find.byType(AllShowsScreen), findsOneWidget);
    expect(find.text(HomeStrings.allShowsListTitle), findsOneWidget);
  });

  testWidgets('공연이 없는 장르를 누르면 준비 중 안내가 뜬다', (tester) async {
    await pumpCategories(tester);

    await tester.tap(find.text('뮤지컬'));
    await tester.pump();

    expect(find.text(HomeStrings.categoryNotReady('뮤지컬')), findsOneWidget);
    expect(find.byType(AllShowsScreen), findsNothing);
  });
}
