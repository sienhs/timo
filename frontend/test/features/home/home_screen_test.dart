import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/app.dart';
import 'package:timo/features/home/constants.dart';
import 'package:timo/features/home/models/refresh_hint.dart';
import 'package:timo/features/home/widgets/home_refresh_hint.dart';
import 'package:timo/features/home/widgets/artist_section.dart';
import 'package:timo/features/home/widgets/home_section_header.dart';
import 'package:timo/features/home/widgets/show_poster_card.dart';

/// 홈 화면과 검색 화면.
///
/// 시안을 옮기는 작업이라 '무엇이 보이는가' 와 '어디로 가는가' 만 본다.
/// 픽셀 값은 시안이 바뀌면 같이 바뀌므로 테스트로 굳히지 않는다.
void main() {
  /// 360 x 800 dp
  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpHome(WidgetTester tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();
  }

  /// 안내 문구는 글자마다 따로 그려서(물결 효과) 렌더 트리에 통 문자열이
  /// 없다. 스크린 리더에 읽히는 값 — 문구에 달아 둔 시맨틱스 라벨로 찾는다.
  ///
  /// `find.bySemanticsLabel` 이 아니라 위젯을 직접 보는 이유: 그쪽은 시맨틱스
  /// 엔진을 켜야 하고, 켜면 테스트마다 핸들을 닫아 줘야 한다.
  /// 스피너도 같은 문구를 라벨로 달고 있으므로(RefreshIndicator
  /// semanticsLabel) 안내 줄 안으로 범위를 좁힌다.
  Finder hintText(RefreshHint hint) => find.descendant(
    of: find.byType(HomeRefreshHint),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Semantics && widget.properties.label == hint.plainText,
      description: '안내 문구 "${hint.plainText}"',
    ),
  );

  /// 안내 줄이 열려 있는지. 접힌 줄도 트리에는 남아 있어서 문구를 못 찾는
  /// 것만으로는 접혔다고 말할 수 없다.
  bool isHintOpen(WidgetTester tester) =>
      tester.widget<HomeRefreshHint>(find.byType(HomeRefreshHint)).visible;

  bool isRefreshing(WidgetTester tester) =>
      tester.widget<HomeRefreshHint>(find.byType(HomeRefreshHint)).refreshing;

  /// 손을 뗀 뒤 새로 고침이 실제로 시작되는 프레임까지 넘긴다. 스피너가
  /// 제자리에 앉는 애니메이션이 끝나야 시작되므로 몇 프레임이 걸린다.
  Future<void> pumpUntilRefreshing(WidgetTester tester) async {
    for (var frame = 0; frame < 60 && !isRefreshing(tester); frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(isRefreshing(tester), isTrue, reason: '새로 고침이 시작되지 않았다');
  }

  /// 홈은 ListView 라 화면 밖 섹션은 아직 만들어지지도 않았다. 찾으려는
  /// 위젯이 실제로 생길 때까지 내린다.
  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }

  /// '더보기' 는 아티스트 섹션과 오픈 임박 섹션에 모두 있다. 어느 섹션의
  /// 것인지 제목으로 좁힌다.
  Finder moreButtonOf(String sectionTitle, String moreLabel) =>
      find.descendant(
        of: find.ancestor(
          of: find.text(sectionTitle),
          matching: find.byType(HomeSectionHeader),
        ),
        matching: find.text(moreLabel),
      );

  testWidgets('홈에 시안의 섹션이 모두 있다', (tester) async {
    await pumpHome(tester);

    expect(find.text(HomeStrings.logo), findsOneWidget);
    expect(find.text(HomeStrings.searchHint), findsOneWidget);

    // 아래쪽 섹션은 화면 밖이라 스크롤해서 확인한다.
    for (final title in [
      HomeStrings.artistSection,
      HomeStrings.ticketOpenSection,
      HomeStrings.popularSection,
    ]) {
      await scrollTo(tester, find.text(title));
      expect(find.text(title), findsOneWidget);
    }
  });

  testWidgets('인기 아티스트는 시안 순서대로 7명 + 더보기다', (tester) async {
    await pumpHome(tester);

    await scrollTo(tester, find.text(HomeStrings.artistSection));

    for (final name in [
      '김준수',
      '옥주현',
      '검정치마',
      '정명훈',
      '아이유',
      '박보검',
      '페기구',
    ]) {
      expect(find.text(name), findsOneWidget, reason: '$name 이 없다');
    }
    expect(
      find.descendant(
        of: find.byType(ArtistSection),
        matching: find.text(HomeStrings.artistMore),
      ),
      findsOneWidget,
    );
  });

  testWidgets('손을 떼기 전 당기는 중부터 안내 문구가 보인다', (tester) async {
    await pumpHome(tester);

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(ListView).first));
    await gesture.moveBy(const Offset(0, 150));
    await tester.pump();
    await tester.pump(HomeMetrics.refreshHintTransition);

    expect(hintText(HomeStrings.refreshHints.first), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('아래로 당기면 안내 문구와 함께 새로 고치고, 끝나면 접힌다', (tester) async {
    await pumpHome(tester);

    await tester.fling(
      find.byType(ListView).first,
      const Offset(0, 400),
      1000,
    );
    await tester.pump();
    await tester.pump(HomeMetrics.refreshHintTransition);

    expect(hintText(HomeStrings.refreshHints.first), findsOneWidget);
    expect(isHintOpen(tester), isTrue);

    // 새로 고침이 끝나면 안내 줄은 접힌다.
    await tester.pumpAndSettle();
    expect(isHintOpen(tester), isFalse);
  });

  testWidgets('손을 떼면 강조 낱말이 한 번 튀어올랐다가 제자리로 돌아온다', (tester) async {
    await pumpHome(tester);

    // 첫 문구의 강조 낱말.
    const highlight = '기다리고';
    double highlightTop() => tester.getTopLeft(find.text(highlight)).dy;

    await tester.fling(
      find.byType(ListView).first,
      const Offset(0, 400),
      1000,
    );
    await tester.pump();

    // 당기는 중에는 아직 튀지 않는다.
    expect(isRefreshing(tester), isFalse);

    // 손을 뗀 뒤 새로 고침이 시작되는 프레임이 점프의 출발점이다.
    await pumpUntilRefreshing(tester);
    final resting = highlightTop();

    // 올라가고,
    await tester.pump(HomeMetrics.refreshJumpDuration ~/ 4);
    expect(highlightTop(), lessThan(resting));

    // 한 번만 튀고 제자리로 돌아온다 — 계속 흔들리지 않는다.
    await tester.pump(HomeMetrics.refreshJumpDuration);
    expect(highlightTop(), closeTo(resting, 0.5));

    await tester.pumpAndSettle();
  });

  testWidgets('당길 때마다 다음 문구가 나온다', (tester) async {
    await pumpHome(tester);

    Future<void> pullAndRelease() async {
      await tester.fling(
        find.byType(ListView).first,
        const Offset(0, 400),
        1000,
      );
      await tester.pump();
      await tester.pump(HomeMetrics.refreshHintTransition);
    }

    await pullAndRelease();
    expect(hintText(HomeStrings.refreshHints[0]), findsOneWidget);
    await tester.pumpAndSettle();

    await pullAndRelease();
    expect(hintText(HomeStrings.refreshHints[1]), findsOneWidget);
    expect(hintText(HomeStrings.refreshHints[0]), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('아티스트 칸의 탭 하이라이트는 원이 아니라 둥근 사각형이다', (tester) async {
    await pumpHome(tester);
    await scrollTo(tester, find.text(HomeStrings.artistSection));

    final cell = tester.widget<InkWell>(
      find
          .descendant(
            of: find.byType(ArtistSection),
            matching: find.byType(InkWell),
          )
          .first,
    );

    // 원으로 자르면 칸(아바타 + 이름)보다 원이 커서 아바타 밖으로 비어져
    // 나온 원이 그려진다.
    expect(cell.customBorder, isNull);
    expect(
      cell.borderRadius,
      BorderRadius.circular(HomeMetrics.artistCellRadius),
    );
  });

  testWidgets('검색 화면이 없어 검색 바를 누르면 준비 중 안내가 뜬다', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.text(HomeStrings.searchHint));
    await tester.pumpAndSettle();

    expect(find.text(HomeStrings.searchNotReady), findsOneWidget);
  });

  testWidgets('아티스트를 누르면 준비 중 안내가 뜬다', (tester) async {
    await pumpHome(tester);

    await scrollTo(tester, find.text('옥주현'));
    await tester.tap(find.text('옥주현'));
    await tester.pumpAndSettle();

    expect(find.text(HomeStrings.artistNotReady('옥주현')), findsOneWidget);
  });

  testWidgets('목록 화면이 없는 더보기를 누르면 준비 중 안내가 뜬다', (tester) async {
    await pumpHome(tester);

    await scrollTo(tester, find.text(HomeStrings.ticketOpenSection));

    await tester.tap(
      moreButtonOf(HomeStrings.ticketOpenSection, HomeStrings.ticketOpenMore),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(HomeStrings.moreNotReady(HomeStrings.ticketOpenSection)),
      findsOneWidget,
    );
  });

  testWidgets('인기 공연 카드에는 순위 뱃지가 붙는다', (tester) async {
    await pumpHome(tester);

    // 카드는 제목보다 아래에 있어 제목이 보이는 시점엔 아직 안 만들어졌다.
    await scrollTo(tester, find.text(HomeStrings.rank(1)));

    expect(find.text(HomeStrings.rank(1)), findsOneWidget);
    expect(find.text(HomeStrings.rank(2)), findsOneWidget);
    expect(find.byType(ShowPosterCard), findsWidgets);
  });

  group('티켓 오픈 뱃지 문구', () {
    final now = DateTime(2026, 10, 20, 9);

    test('오늘 오픈이면 시각을 읽어 준다', () {
      expect(
        HomeStrings.ticketOpen(DateTime(2026, 10, 20, 14), now: now),
        '오늘 14:00 오픈',
      );
    });

    test('임박한 날짜는 며칠 남았는지로 읽어 준다', () {
      expect(
        HomeStrings.ticketOpen(DateTime(2026, 10, 25, 14), now: now),
        '5일 후 오픈',
      );
    });

    test('먼 날짜는 날짜와 요일을 그대로 읽어 준다', () {
      expect(
        HomeStrings.ticketOpen(DateTime(2026, 12, 25, 14), now: now),
        '12.25 (금) 오픈',
      );
    });

    test('자정을 넘기면 남은 시간이 24시간 미만이어도 1일 후다', () {
      // Duration.inDays 로 세면 0(=오늘)이 나와 '오늘 오픈' 으로 잘못 읽힌다.
      expect(
        HomeStrings.ticketOpen(DateTime(2026, 10, 21, 8), now: now),
        '1일 후 오픈',
      );
    });
  });
}
