import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/theme/app_theme.dart';
import 'package:timo/core/widgets/error_snack_bar.dart';

/// 앱 공통 안내 상자(오류·성공·안내)의 모양 계약.
///
/// 색으로 셋을 구분하던 테두리를 걷어냈으므로, 이제 상자를 보이게 하는 것은
/// 그림자뿐이다. 그림자가 그려지는 조건을 여기서 굳혀 둔다 — 이 조건이 깨지면
/// 흰 배경 위의 흰 상자가 통째로 안 보이는데, 문구는 그대로 읽혀서 눈으로
/// 훑다가는 놓치기 쉽다.
void main() {
  /// 버튼 하나를 눌러 안내를 띄우는 화면.
  Widget host(void Function(BuildContext context) show) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => show(context),
          child: const Text('띄우기'),
        ),
      ),
    ),
  );

  Future<SnackBar> showAndFind(
    WidgetTester tester,
    void Function(BuildContext context) show,
  ) async {
    await tester.pumpWidget(host(show));
    await tester.tap(find.text('띄우기'));
    await tester.pump();
    return tester.widget<SnackBar>(find.byType(SnackBar));
  }

  /// 안내 문구를 감싼 상자의 꾸밈. 상자는 SnackBar 안쪽 Container 가 그린다.
  BoxDecoration boxOf(WidgetTester tester, String message) {
    final container = tester.widget<Container>(
      find
          .ancestor(
            of: find.text(toastText(message)),
            matching: find.byType(Container),
          )
          .first,
    );
    return container.decoration! as BoxDecoration;
  }

  testWidgets('안내 상자에는 색 테두리가 없고 그림자가 경계를 만든다', (tester) async {
    await showAndFind(tester, (context) => showErrorSnackBar(context, '실패했어요'));

    final box = boxOf(tester, '실패했어요');
    expect(box.border, isNull, reason: '색 테두리는 걷어냈다');
    expect(box.boxShadow, isNotNull, reason: '그림자가 유일한 경계다');
    expect(box.boxShadow, isNotEmpty);
  });

  testWidgets('상자를 자르지 않는다 — 자르면 그림자가 잘려 경계가 사라진다', (tester) async {
    final snackBar = await showAndFind(
      tester,
      (context) => showInfoSnackBar(context, '준비 중이에요'),
    );

    // SnackBar 의 기본값은 hardEdge 다. 그대로 두면 상자 밖으로 퍼지는 그림자가
    // 잘려 나가 흰 배경 위에서 상자가 보이지 않는다.
    expect(snackBar.clipBehavior, Clip.none);
    expect(snackBar.backgroundColor, Colors.transparent);
  });

  testWidgets('오류·성공·안내가 같은 모양으로 뜬다', (tester) async {
    final decorations = <BoxDecoration>[];
    for (final show in [
      (BuildContext context) => showErrorSnackBar(context, '같은 모양'),
      (BuildContext context) => showSuccessSnackBar(context, '같은 모양'),
      (BuildContext context) => showInfoSnackBar(context, '같은 모양'),
    ]) {
      await showAndFind(tester, show);
      decorations.add(boxOf(tester, '같은 모양'));
    }

    expect(decorations[0].color, decorations[1].color);
    expect(decorations[1].color, decorations[2].color);
    expect(decorations[0].border, decorations[1].border);
    expect(decorations[1].border, decorations[2].border);
  });

  testWidgets('토스트는 2초 동안 떠 있다', (tester) async {
    final snackBar = await showAndFind(
      tester,
      (context) => showInfoSnackBar(context, '잠깐 떠요'),
    );
    expect(snackBar.duration, const Duration(seconds: 2));
  });

  testWidgets('화면 읽기는 줄 바꿈 기호가 들어가기 전 문구로 한다', (tester) async {
    const message = '저장하지 못했어요. 다시 시도해주세요.';
    await showAndFind(tester, (context) => showErrorSnackBar(context, message));

    final text = tester.widget<Text>(find.text(toastText(message)));
    expect(text.semanticsLabel, message);
  });

  group('토스트 문구', () {
    /// 폭 없는 단어 묶음 기호를 걷어낸, 눈에 보이는 그대로의 문구.
    String visible(String message) =>
        toastText(message).replaceAll('\u2060', '');

    test('문장이 둘이면 문장 사이에서 줄을 넘긴다', () {
      expect(
        visible('오픈 알림을 신청했어요. 예매가 열리기 전에 알려드릴게요.'),
        '오픈 알림을 신청했어요.\n예매가 열리기 전에 알려드릴게요.',
      );
      expect(visible('정말요? 네!'), '정말요?\n네!');
    });

    test('이미 줄을 나눠 둔 문구는 그대로 둔다', () {
      expect(
        visible('인증번호 요청 횟수를 초과했어요.\n잠시 후 다시 시도해주세요'),
        '인증번호 요청 횟수를 초과했어요.\n잠시 후 다시 시도해주세요',
      );
    });

    test('한 문장이거나 끝에 공백이 있으면 줄을 넘기지 않는다', () {
      expect(visible('마켓에 등록했어요'), '마켓에 등록했어요');
      expect(visible('로그인이 필요해요. '), '로그인이 필요해요. ');
    });

    testWidgets('폭이 모자라면 단어 중간이 아니라 띄어쓰기에서 넘어간다', (tester) async {
      /// [text] 를 [width] 폭에 그렸을 때 줄마다의 글자(기호 제외, 앞뒤 공백 제외).
      List<String> linesOf(String text, double width) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: const TextStyle(fontSize: 14)),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: width);
        final lines = <String>[];
        var start = 0;
        while (start < text.length) {
          final end = painter.getLineBoundary(TextPosition(offset: start)).end;
          if (end <= start) break;
          lines.add(text.substring(start, end).replaceAll('\u2060', '').trim());
          start = end;
          while (start < text.length && '\n '.contains(text[start])) {
            start++;
          }
        }
        return lines;
      }

      const message = '찜을 저장하지 못했어요. 잠시 후 다시 시도해주세요.';
      // 테스트 글꼴은 글자마다 폭이 글자 크기와 같다. 9칸이면 그냥 그렸을 때
      // "못" / "했어요" 처럼 단어 중간에서 끊긴다.
      expect(linesOf(message, 14 * 9).first, '찜을 저장하지 못');
      expect(linesOf(toastText(message), 14 * 9), [
        '찜을 저장하지',
        '못했어요.',
        '잠시 후 다시',
        '시도해주세요.',
      ]);
    });
  });

  testWidgets('아래 여백은 기본이 하단 고정 버튼 높이고, 주면 그 값을 쓴다', (tester) async {
    final fallback = await showAndFind(
      tester,
      (context) => showErrorSnackBar(context, '기본 여백'),
    );
    expect((fallback.margin! as EdgeInsets).bottom, 80);

    final given = await showAndFind(
      tester,
      (context) =>
          showInfoSnackBar(context, '지정 여백', bottomMargin: snackBarGapAboveBar),
    );
    expect((given.margin! as EdgeInsets).bottom, snackBarGapAboveBar);
  });
}
