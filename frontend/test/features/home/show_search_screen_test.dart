import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/app.dart';
import 'package:timo/features/home/constants.dart';
import 'package:timo/features/home/data/mock_home_api.dart';
import 'package:timo/features/home/widgets/show_search_result_tile.dart';
import 'package:timo/features/show/screens/show_detail_screen.dart';

/// 공연 검색 화면. 홈에서 들어가 검색어를 제출하고 결과가 무엇인지만 본다.
void main() {
  /// 360 x 800 dp
  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// 홈에서 검색 바를 눌러 검색 화면까지 간다.
  Future<void> pumpSearch(WidgetTester tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      const App(homeApi: MockHomeApi(latency: Duration.zero)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(HomeStrings.searchHint));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester, String keyword) async {
    await tester.enterText(find.byType(TextField), keyword);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
  }

  testWidgets('검색 전에는 안내 문구만 있다', (tester) async {
    await pumpSearch(tester);

    expect(find.text(HomeStrings.searchIdle), findsOneWidget);
    expect(find.byType(ShowSearchResultTile), findsNothing);
  });

  testWidgets('검색어를 제출하면 제목이 맞는 공연이 줄로 나온다', (tester) async {
    await pumpSearch(tester);

    await submit(tester, '콘서트');

    final matched = MockHomeApi.all.where((s) => s.title.contains('콘서트'));
    expect(find.byType(ShowSearchResultTile), findsNWidgets(matched.length));
    for (final show in matched) {
      expect(find.text(show.title), findsOneWidget);
      expect(find.text(show.venueName), findsOneWidget);
    }
  });

  testWidgets('맞는 공연이 없으면 검색어를 되비춘 빈 결과 문구가 나온다', (tester) async {
    await pumpSearch(tester);

    await submit(tester, '없는공연');

    expect(find.text(HomeStrings.searchEmpty('없는공연')), findsOneWidget);
    expect(find.byType(ShowSearchResultTile), findsNothing);
  });

  testWidgets('빈 검색어는 요청하지 않는다', (tester) async {
    await pumpSearch(tester);

    await submit(tester, '   ');

    expect(find.text(HomeStrings.searchIdle), findsOneWidget);
  });

  testWidgets('결과 줄을 누르면 상세가 열린다', (tester) async {
    await pumpSearch(tester);
    await submit(tester, '아이유');

    await tester.tap(find.byType(ShowSearchResultTile).first);
    await tester.pumpAndSettle();

    expect(find.byType(ShowDetailScreen), findsOneWidget);
  });
}
