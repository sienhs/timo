import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:timo/features/shell/constants.dart';
import 'package:timo/main.dart' as app;
import 'package:timo/features/memory/widgets/creator/concert_card.dart';
import 'package:timo/features/memory/widgets/viewer/memory_ticket_card.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'five steps, native photo processing, flip, hold video and collection restore',
    (tester) async {
      Future<void> waitFor(Finder finder) async {
        for (var i = 0; i < 160; i++) {
          await tester.pump(const Duration(milliseconds: 250));
          if (finder.evaluate().isNotEmpty) return;
        }
        // 무엇이 떠 있는지 같이 남긴다. 화면이 바뀌어 단언이 낡았을 때
        // 로그만 보고 바로 알 수 있다.
        final texts = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '')
            .whereType<String>()
            .toList();
        fail('Expected UI state did not appear. 화면의 텍스트: $texts');
      }

      Future<void> tapText(String value) async {
        // 나타날 때까지 기다린 뒤 누른다. 등장 연출(Reveal)이 opacity 0 에서
        // 시작하는데, Opacity 는 0 일 때 자식을 시맨틱스·히트테스트에서
        // 빼기 때문에 한 프레임만 기다리면 아직 못 누른다.
        await waitFor(find.text(value));
        final finder = find.text(value);
        await tester.ensureVisible(finder.first);
        await tester.tap(finder.first);
        await tester.pump();
      }

      Future<void> tapLabel(String value) async {
        // 사진 타일은 이름을 텍스트가 아니라 시맨틱스 라벨로 달고 있다.
        await waitFor(find.bySemanticsLabel(value));
        final finder = find.bySemanticsLabel(value);
        await tester.ensureVisible(finder.first);
        await tester.tap(finder.first);
        await tester.pump();
      }

      await app.main();
      // 앱은 홈 셸에서 시작한다. 소장품은 빠른 메뉴의 '컬렉션' 으로 들어간다.
      await waitFor(find.bySemanticsLabel(ShellStrings.openQuickMenu));
      await tester.tap(find.bySemanticsLabel(ShellStrings.openQuickMenu));
      await tester.pump();
      await tapText('컬렉션');
      await waitFor(find.byTooltip('새 소장품 만들기'));
      await tester.tap(find.byTooltip('새 소장품 만들기'));
      await tester.pump();
      await waitFor(find.text('1/5'));
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ConcertCard, '빛으로 남은 밤'),
          matching: find.text('NFT 소장품 만들기'),
        ),
      );
      await tester.pump();
      await waitFor(find.text('2/5'));
      await tapLabel('데모 무대 1');
      await waitFor(find.text('다음으로'));
      await tapText('다음으로');
      await waitFor(find.text('3/5'));
      await tapLabel('분석 테스트 사진');
      await waitFor(find.text('다음으로'));
      // 누끼가 실제로 돌았는지만 본다. MODNet 이 뜨면 '정밀 누끼 완료',
      // ML Kit 으로 떨어지면 '기본 누끼로 처리했어요' 라 엔진까지 못 박으면
      // 기기·모델 상황에 따라 흔들린다. 못 박아야 할 것은 '원본 사진 데모'
      // (= 누끼가 아예 안 돌았다)가 아니라는 사실이다.
      expect(find.textContaining('원본 사진 데모'), findsNothing);
      expect(
        find.textContaining('정밀 누끼 완료').evaluate().isNotEmpty ||
            find.textContaining('기본 누끼로 처리했어요').evaluate().isNotEmpty,
        true,
        reason: '누끼 결과 문구가 보이지 않는다',
      );
      await tapText('다음으로');
      await waitFor(find.text('4/5'));
      await tapLabel('분석 테스트 사진');
      await waitFor(find.text('다음으로'));
      // 두 사람이 모두 배치 에디터에 올라와야 한다. 예전에는 사람마다
      // '인물 N 크기' 슬라이더가 있었는데, 직접 끌어 옮기는 에디터로 바뀌면서
      // 사람 선택 칩만 남았다.
      await waitFor(find.text('인물 2'));
      await tester.ensureVisible(find.text('인물 2'));
      await tester.pump(const Duration(seconds: 1));
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      final folder0 = await getApplicationDocumentsDirectory();
      await File('${folder0.path}/editor_preview.png')
          .writeAsBytes(await binding.takeScreenshot('editor_preview'));
      await tapText('다음으로');
      await waitFor(find.text('5/5'));
      // 이펙트 타일은 이름을 눈에 보이는 글자로도 달고 있다. 시맨틱스 라벨은
      // 타일 안 글자와 병합돼 정확히 일치하지 않으므로 글자로 찾는다.
      await tapText('레이저');
      await tapText('다음으로');
      // '제작중' 단계. 제작이 끝나야 완료 버튼이 열린다.
      //
      // 제목은 StaggeredText 가 단어별 Text 로 쪼개 그리므로 문장 전체로는
      // 찾을 수 없다. 조각 하나로 찾는다.
      await waitFor(find.textContaining('완성되었어요'));
      await tapText('완료하기');
      await waitFor(find.byType(MemoryTicketCard));
      await tester.pump(const Duration(seconds: 2));
      expect(
        find.text('빛으로 남은 밤'),
        findsNothing,
        reason: 'front must not contain concert details',
      );
      final folder = await getApplicationDocumentsDirectory();
      Future<void> shot(String name) async {
        final data = await binding.takeScreenshot(name);
        await File('${folder.path}/$name.png').writeAsBytes(data);
      }

      await shot('ticket_front');
      final card = find.byType(MemoryTicketCard);
      await tester.drag(card, const Offset(120, 0));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('빛으로 남은 밤'), findsOneWidget);
      await shot('ticket_back');
      await tester.drag(card, const Offset(-120, 0));
      await tester.pump(const Duration(milliseconds: 700));
      final center = tester.getCenter(card);
      final hold = await tester.startGesture(center);
      // First frame after pointer-down starts the ticker (elapsed 0); the
      // second frame shows the light gathering.
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 364));
      await shot('ticket_hold');
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pump(const Duration(milliseconds: 750));
      final player = tester.widget<VideoPlayer>(find.byType(VideoPlayer));
      expect(player.controller.value.isPlaying, true);
      await shot('ticket_video');
      await hold.up();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 400));
      await shot('ticket_fullscreen');
      expect(
        player.controller.value.isPlaying,
        true,
        reason: 'released video keeps playing to its end',
      );
      expect(find.byType(VideoPlayer), findsOneWidget);
      // The demo clip is 6s; it must finish, ease out and rewind by itself.
      for (
        var i = 0;
        i < 60 && find.byType(VideoPlayer).evaluate().isNotEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.byType(VideoPlayer), findsNothing);
      await tester.pump(const Duration(milliseconds: 400));
      expect(player.controller.value.isPlaying, false);
      expect(player.controller.value.position, Duration.zero);
      await tester.tap(find.byTooltip('소장품 목록으로'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('빛으로 남은 밤'), findsWidgets);
      await shot('collection');
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
