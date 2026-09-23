import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timo/core/theme/app_theme.dart';
import 'package:timo/features/notification/constants.dart';
import 'package:timo/features/notification/data/mock_notification_api.dart';
import 'package:timo/features/notification/screens/notification_screen.dart';
import 'package:timo/features/notification/state/notification_api_scope.dart';
import 'package:timo/routes/app_routes.dart';

/// 알림함 화면. 읽음과 안 읽음을 글자가 아니라 굵기와 점으로 나누므로, 문구가
/// 아니라 굵기가 맞는지를 본다.
void main() {
  const unreadBody = '로이킴 콘서트, 지금부터 입장할 수 있어요';
  const readBody = '내일은 Bruno Mars 내한공연 보는 날이에요';

  /// 목이 들고 있는 일곱 건 중 마지막. 첫 쪽(다섯 건)에는 안 들어 있다.
  const lastBody = '공지: 서비스 점검이 예정되어 있어요';
  const showLabel = '공연 상세';

  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<MockNotificationApi> pumpScreen(
    WidgetTester tester, {
    MockNotificationScenario scenario = MockNotificationScenario.normal,
  }) async {
    usePhoneSize(tester);
    final api = MockNotificationApi(latency: Duration.zero, scenario: scenario);
    await tester.pumpWidget(
      NotificationApiScope(
        api: api,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const NotificationScreen(),
          routes: {
            AppRoutes.showDetail: (_) => const Scaffold(body: Text(showLabel)),
          },
        ),
      ),
    );
    // 목록을 받아 그릴 때까지. 목록 끝의 '더 받는 중' 동그라미가 끝없이 돌아서
    // pumpAndSettle 은 쓸 수 없다.
    await tester.pump();
    await tester.pump();
    // 오른쪽 아래 버튼은 커지며 나타난다. 그 애니메이션이 끝나기 전에는 눌러도
    // 손가락이 닿지 않아 탭이 빗나간다.
    await tester.pump(const Duration(milliseconds: 500));
    return api;
  }

  /// 이 본문을 그린 Text 의 글자 굵기.
  FontWeight? weightOf(WidgetTester tester, String body) =>
      tester.widget<Text>(find.text(body)).style?.fontWeight;

  group('목록', () {
    testWidgets('알림 본문이 최신순으로 보인다', (tester) async {
      await pumpScreen(tester);

      expect(find.text(NotificationStrings.title), findsOneWidget);
      expect(find.text(unreadBody), findsOneWidget);
      expect(find.text(readBody), findsOneWidget);
    });

    testWidgets('안 읽은 알림만 굵게 나온다', (tester) async {
      await pumpScreen(tester);

      expect(weightOf(tester, unreadBody), FontWeight.w600);
      expect(weightOf(tester, readBody), FontWeight.w400);
    });

    testWidgets('여러 줄로 온 본문은 첫 줄만 그린다', (tester) async {
      await pumpScreen(tester);

      // 양도 매물 알림은 요약 아래 '· 공연명' 목록이 붙어 온다. 첫 줄이 그 자체로
      // 요약이라 목록에서는 첫 줄만 그린다.
      final body = tester.widget<Text>(find.textContaining('찜한 공연 3건에'));
      expect(body.data, '찜한 공연 3건에 양도 매물이 올라왔어요');
      expect(body.data, isNot(contains('로이킴')));

      // 그래도 두 줄까지는 그린다. 공연명이 길면 한 줄에 안 들어간다.
      expect(body.maxLines, 2);
      expect(body.overflow, TextOverflow.ellipsis);
    });
  });

  group('알림을 누르면', () {
    testWidgets('읽음으로 바뀌고 그 공연 상세로 간다', (tester) async {
      await pumpScreen(tester);
      expect(weightOf(tester, unreadBody), FontWeight.w600);

      await tester.tap(find.text(unreadBody));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(showLabel), findsOneWidget);
    });

    testWidgets('돌아오면 읽음 표시가 남아 있다', (tester) async {
      // 서버 응답을 기다렸다 바꾸면 이 시점에 아직 안 읽음으로 보인다.
      await pumpScreen(tester);

      await tester.tap(find.text(unreadBody));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      Navigator.of(tester.element(find.text(showLabel))).pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(weightOf(tester, unreadBody), FontWeight.w400);
    });
  });

  group('모두 읽음', () {
    testWidgets('안 읽은 알림이 있으면 버튼이 보인다', (tester) async {
      await pumpScreen(tester);

      expect(find.text(NotificationStrings.markAllRead), findsOneWidget);
    });

    testWidgets('누르면 전부 읽음이 되고 버튼이 사라진다', (tester) async {
      final api = await pumpScreen(tester);

      await tester.tap(find.text(NotificationStrings.markAllRead));
      await tester.pump();
      await tester.pump();
      // 버튼은 작아지며 사라진다. 그동안은 아직 트리에 남아 있다.
      await tester.pump(const Duration(milliseconds: 500));

      expect(weightOf(tester, unreadBody), FontWeight.w400);
      // 누를 일이 없어진 버튼은 흐려지는 게 아니라 아예 내린다. 마지막 알림을
      // 가리지 않게 하려는 것이다.
      expect(find.text(NotificationStrings.markAllRead), findsNothing);
      expect(await api.fetchUnreadCount(), 0);
    });
  });

  group('이어 받기', () {
    testWidgets('첫 쪽이 화면을 못 채우면 스크롤 없이도 다음 쪽을 받는다', (tester) async {
      // 다음 쪽은 스크롤이 끝에 다가올 때 받는데, 목록이 짧으면 스크롤 자체가
      // 안 생겨 그 순간이 영영 안 온다. 그대로 두면 아래쪽 동그라미만 돈다.
      await pumpScreen(tester);
      // 한 쪽은 다섯 건인데 목은 일곱 건을 들고 있다.
      expect(find.text(unreadBody), findsOneWidget);

      // 손대지 않아도 나머지가 따라 들어온다.
      await tester.pump();
      await tester.pump();

      expect(find.text(lastBody), findsOneWidget);
    });
  });

  group('목록이 없거나 실패하면', () {
    testWidgets('받은 알림이 없으면 안내를 보여 준다', (tester) async {
      await pumpScreen(tester, scenario: MockNotificationScenario.empty);

      expect(find.text(NotificationStrings.empty), findsOneWidget);
      // 안 읽은 것도 없으니 버튼도 없다.
      expect(find.text(NotificationStrings.markAllRead), findsNothing);
    });

    testWidgets('불러오기가 실패하면 다시 시도가 보인다', (tester) async {
      await pumpScreen(tester, scenario: MockNotificationScenario.error);

      expect(find.text(AsyncBoundaryRetryLabel.value), findsOneWidget);
    });
  });
}

/// `AsyncBoundary` 의 '다시 시도' 문구. 테스트가 그 위젯의 상수를 직접 들여다보지
/// 않도록 한 겹 둔다.
abstract final class AsyncBoundaryRetryLabel {
  static const value = '다시 시도';
}
