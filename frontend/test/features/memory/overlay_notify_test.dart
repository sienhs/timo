import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/widgets/error_snack_bar.dart';
import 'package:timo/features/memory/widgets/ui/overlay_service.dart';

/// 소장품 화면의 검정 토스트도 줄 바꿈과 떠 있는 시간은 앱 공통 토스트와 같다.
void main() {
  Future<void> notify(WidgetTester tester, String message) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => OverlayService.notify(context, message),
              child: const Text('띄우기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('띄우기'));
    await tester.pump();
  }

  testWidgets('2초 동안 떠 있다', (tester) async {
    await notify(tester, '스토리에 공유했어요');

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.duration, toastDuration);
  });

  testWidgets('문장 사이에서 줄을 넘기고, 화면 읽기는 원래 문구로 한다', (tester) async {
    const message = '사진 처리에 실패했어요. 다시 선택해주세요.';
    await notify(tester, message);

    final text = tester.widget<Text>(find.text(toastText(message)));
    expect(text.data, contains('\n'));
    expect(text.semanticsLabel, message);
  });
}
