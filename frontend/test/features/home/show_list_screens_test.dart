import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/app.dart';
import 'package:timo/features/home/constants.dart';
import 'package:timo/features/home/data/mock_home_api.dart';
import 'package:timo/features/home/models/show_filters.dart';
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

  group('공연 전체 조회 — 날짜·정렬', () {
    final api = _DatedApi();

    /// 날짜 칩을 눌러 시트를 열고 빠른 선택 하나를 고른다.
    Future<void> pickPreset(WidgetTester tester, String preset) async {
      await tester.tap(find.text(HomeStrings.dateFilterAll));
      await tester.pumpAndSettle();
      await tester.tap(find.text(preset));
      await tester.pumpAndSettle();
    }

    testWidgets('전체 기간 · 인기순으로 시작한다', (tester) async {
      await pumpScreen(tester, AppRoutes.allShows, api: api);

      expect(find.text(HomeStrings.dateFilterAll), findsOneWidget);
      expect(find.text(ShowSort.popular.label), findsOneWidget);
      expect(find.text('${HomeStrings.bookableTab} 3'), findsOneWidget);
    });

    testWidgets('다음 달을 고르면 그 달 공연만 남고 탭 숫자도 따라간다', (tester) async {
      await pumpScreen(tester, AppRoutes.allShows, api: api);

      await pickPreset(tester, HomeStrings.presetNextMonth);
      expect(find.text(HomeStrings.dateSheetApply(1)), findsOneWidget);
      await tester.tap(find.text(HomeStrings.dateSheetApply(1)));
      await tester.pumpAndSettle();

      final range = ShowDatePreset.nextMonth.rangeFrom(DateTime.now())!;
      expect(find.text(range.label), findsOneWidget);
      expect(find.text('${HomeStrings.bookableTab} 1'), findsOneWidget);
      expect(find.text(_DatedApi.nextMonth.title), findsOneWidget);
      expect(find.text(_DatedApi.soon.title), findsNothing);
      expect(find.text(_DatedApi.far.title), findsNothing);
    });

    testWidgets('칩의 × 로 기간을 풀면 전체로 돌아온다', (tester) async {
      await pumpScreen(tester, AppRoutes.allShows, api: api);
      await pickPreset(tester, HomeStrings.presetNextMonth);
      await tester.tap(find.text(HomeStrings.dateSheetApply(1)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(HomeStrings.dateFilterClear));
      await tester.pumpAndSettle();

      expect(find.text(HomeStrings.dateFilterAll), findsOneWidget);
      expect(find.text('${HomeStrings.bookableTab} 3'), findsOneWidget);
    });

    testWidgets('기간에 공연이 없으면 기간 탓이라고 알려 준다', (tester) async {
      await pumpScreen(tester, AppRoutes.allShows, api: api);

      await pickPreset(tester, HomeStrings.presetThisWeekend);
      await tester.tap(find.text(HomeStrings.dateSheetApply(0)));
      await tester.pumpAndSettle();

      expect(find.text(HomeStrings.emptyInDateRange), findsOneWidget);
    });

    testWidgets('공연일 빠른 순으로 바꾸면 카드 순서가 바뀐다', (tester) async {
      await pumpScreen(tester, AppRoutes.allShows, api: api);

      double topOf(ShowSummary show) =>
          tester.getTopLeft(find.text(show.title)).dy;

      // 인기순(받은 순서): 먼 것 → 다음 달 → 곧.
      expect(topOf(_DatedApi.far), lessThan(topOf(_DatedApi.nextMonth)));

      await tester.tap(find.text(ShowSort.popular.label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ShowSort.startDate.label).last);
      await tester.pumpAndSettle();

      expect(find.text(ShowSort.startDate.label), findsOneWidget);
      expect(topOf(_DatedApi.soon), lessThan(topOf(_DatedApi.nextMonth)));
      expect(topOf(_DatedApi.nextMonth), lessThan(topOf(_DatedApi.far)));
    });
  });
}

/// 오늘을 기준으로 상대 날짜에 공연 셋을 두는 서버. 실행 날짜가 달라도 "곧 ·
/// 다음 달 · 석 달 뒤" 관계가 유지되어 빠른 선택(다음 달)이 늘 하나만 잡는다.
class _DatedApi extends MockHomeApi {
  _DatedApi() : super(latency: Duration.zero);

  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// 인기 1위인데 가장 멀다. 정렬을 바꾸면 맨 뒤로 가야 한다.
  static final far = ShowSummary(
    id: 101,
    title: '석 달 뒤 공연',
    venueName: '먼 곳',
    status: ShowSummary.onSaleStatus,
    startAt: DateTime(_today.year, _today.month + 3, 1),
  );

  /// 다음 달 5일부터 7일까지. 주말 프리셋에는 절대 걸리지 않는 날이 아니라
  /// "다음 달" 프리셋에만 걸리면 된다.
  static final nextMonth = ShowSummary(
    id: 102,
    title: '다음 달 공연',
    venueName: '가까운 곳',
    status: ShowSummary.upcomingStatus,
    startAt: DateTime(_today.year, _today.month + 1, 5),
    endAt: DateTime(_today.year, _today.month + 1, 7),
    ticketOpenAt: _today.add(const Duration(days: 3)),
  );

  /// 곧. 오늘부터 이틀 뒤라 이번 달일 수도, 다음 달일 수도 있어 다음 달
  /// 프리셋 테스트가 안 흔들리도록 다음 달 1일 앞으로 잡는다 — 이틀 뒤가
  /// 다음 달이 되는 월말이면 그 대신 오늘로 둔다.
  static final soon = ShowSummary(
    id: 103,
    title: '곧 하는 공연',
    venueName: '바로 옆',
    status: ShowSummary.onSaleStatus,
    startAt: _soonDate,
  );

  static DateTime get _soonDate {
    final candidate = DateTime(_today.year, _today.month, _today.day + 2);
    return candidate.month == _today.month ? candidate : _today;
  }

  @override
  Future<List<ShowSummary>> fetchAllShows() async => [far, nextMonth, soon];
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
