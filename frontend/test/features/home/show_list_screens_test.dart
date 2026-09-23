import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/app.dart';
import 'package:timo/features/home/constants.dart';
import 'package:timo/features/home/data/mock_home_api.dart';
import 'package:timo/features/home/models/show_summary.dart';
import 'package:timo/features/home/widgets/show_banner_card.dart';
import 'package:timo/features/show/screens/show_detail_screen.dart';
import 'package:timo/routes/app_routes.dart';

/// 더보기로 들어가는 목록 화면 둘. 검색·빈 상태는 같은 위젯(`ShowListView`)
/// 이라 한쪽에서만 보고, 나머지는 무엇을 거르는가와 탭이 무엇을 가르는가만
/// 본다.
void main() {
  /// 360 x 800 dp
  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    String route, {
    MockHomeApi api = const MockHomeApi(latency: Duration.zero),
  }) async {
    usePhoneSize(tester);
    await tester.pumpWidget(App(initialRoute: route, homeApi: api));
    await tester.pumpAndSettle();
  }

  Future<void> typeSearch(WidgetTester tester, String keyword) async {
    await tester.enterText(find.byType(TextField), keyword);
    await tester.pumpAndSettle();
  }

  /// 목록은 한 화면에 카드 서너 장만 만든다. 아래쪽 카드는 스크롤해야 생긴다.
  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      200,
      // 화면에 Scrollable 이 여럿이다(검색 칸도 하나 만든다). 목록의 것을 짚는다.
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  group('오픈 예정 공연 목록', () {
    testWidgets('오픈 예정 공연만 세우고 제목이 섹션과 같다', (tester) async {
      await pumpScreen(tester, AppRoutes.openSoonShows);

      expect(find.text(HomeStrings.openSoonListTitle), findsOneWidget);
      expect(find.text(MockHomeApi.blackSkirt.title), findsOneWidget);
      expect(find.text(MockHomeApi.remind.title), findsOneWidget);
      // 이미 예매중인 공연은 오픈 예정 목록에 없다.
      expect(find.text(MockHomeApi.iu.title), findsNothing);
    });

    testWidgets('검색 칸에 친 말로 그 자리에서 걸러진다', (tester) async {
      await pumpScreen(tester, AppRoutes.openSoonShows);

      await typeSearch(tester, '검정치마');

      expect(find.text(MockHomeApi.blackSkirt.title), findsOneWidget);
      expect(find.text(MockHomeApi.remind.title), findsNothing);
    });

    testWidgets('걸러서 남은 게 없으면 검색어를 되비춰 준다', (tester) async {
      await pumpScreen(tester, AppRoutes.openSoonShows);

      await typeSearch(tester, '없는공연');

      expect(find.text(HomeStrings.searchEmpty('없는공연')), findsOneWidget);
    });

    testWidgets('오픈 시각이 지난 공연은 세우지 않는다', (tester) async {
      await pumpScreen(tester, AppRoutes.openSoonShows, api: _StaleOpenApi());

      expect(find.text(_StaleOpenApi.staleTitle), findsNothing);
      expect(find.text(MockHomeApi.blackSkirt.title), findsOneWidget);
    });

    testWidgets('카드를 누르면 그 공연 상세로 간다', (tester) async {
      await pumpScreen(tester, AppRoutes.openSoonShows);

      await tester.tap(find.byType(ShowBannerCard).first);
      await tester.pumpAndSettle();

      expect(find.byType(ShowDetailScreen), findsOneWidget);
    });
  });

  group('공연 전체 조회', () {
    testWidgets('예매 가능 탭으로 시작해 끝난 공연을 빼고 센다', (tester) async {
      await pumpScreen(tester, AppRoutes.allShows);

      expect(find.text(HomeStrings.allShowsListTitle), findsOneWidget);
      // 목 데이터 여섯 건 중 페기구만 끝난 공연이다.
      expect(find.text('${HomeStrings.bookableTab} 5'), findsOneWidget);
      expect(find.text('${HomeStrings.allTab} 6'), findsOneWidget);
      expect(find.text(MockHomeApi.peggyGou.title), findsNothing);
    });

    testWidgets('모두 보기로 바꾸면 끝난 공연까지 나온다', (tester) async {
      await pumpScreen(tester, AppRoutes.allShows);

      await tester.tap(find.text('${HomeStrings.allTab} 6'));
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text(MockHomeApi.peggyGou.title));
      expect(find.text(MockHomeApi.peggyGou.title), findsOneWidget);
    });

    testWidgets('탭을 바꿔도 쳐 둔 검색어는 그대로다', (tester) async {
      await pumpScreen(tester, AppRoutes.allShows);

      await typeSearch(tester, '페기구');
      expect(find.text(HomeStrings.searchEmpty('페기구')), findsOneWidget);

      await tester.tap(find.text('${HomeStrings.allTab} 6'));
      await tester.pumpAndSettle();

      expect(find.text(MockHomeApi.peggyGou.title), findsOneWidget);
      expect(find.text(MockHomeApi.iu.title), findsNothing);
    });
  });
}

/// 오픈 시각이 지났는데도 오픈 예정(SCHEDULED)으로 남은 공연을 섞어 주는 서버.
class _StaleOpenApi extends MockHomeApi {
  _StaleOpenApi() : super(latency: Duration.zero);

  static const staleTitle = '상태가 안 밀린 공연';

  @override
  Future<List<ShowSummary>> fetchTicketOpenAll() async => [
    ShowSummary(
      id: 99,
      title: staleTitle,
      venueName: '고척돔',
      status: ShowSummary.upcomingStatus,
      startAt: DateTime(2026, 12, 1),
      ticketOpenAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    MockHomeApi.blackSkirt,
  ];
}
