import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo_gate/core/theme/app_theme.dart';
import 'package:timo_gate/features/scan/constants.dart';
import 'package:timo_gate/features/scan/models/verification_result.dart';
import 'package:timo_gate/features/scan/widgets/scan_result_view.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    VerificationResult result, {
    VoidCallback? onDismiss,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: ScanResultView(result: result, onDismiss: onDismiss ?? () {}),
    ),
  );

  testWidgets('입장 허용은 버튼 없이 제목만, 아무 데나 누르면 닫힌다', (tester) async {
    var dismissed = 0;
    await pump(tester, const Admitted(), onDismiss: () => dismissed++);

    expect(find.text(ScanStrings.admitted), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);

    await tester.tap(find.text(ScanStrings.admitted));
    expect(dismissed, 1);
  });

  testWidgets('거절은 사유·안내·두 버튼을 보이고 버튼으로 닫힌다', (tester) async {
    var dismissed = 0;
    await pump(
      tester,
      const Rejected(reason: RejectReason.alreadyUsed),
      onDismiss: () => dismissed++,
    );

    expect(find.text(ScanStrings.rejected), findsOneWidget);
    expect(find.text(RejectReason.alreadyUsed.label), findsOneWidget);
    expect(find.text(ScanStrings.rejectedGuide), findsOneWidget);

    await tester.tap(find.text(ScanStrings.nextQr));
    await tester.tap(find.text(ScanStrings.confirm));
    expect(dismissed, 2);
  });

  testWidgets('거절 화면은 바탕을 눌러도 닫히지 않는다', (tester) async {
    var dismissed = 0;
    await pump(
      tester,
      const Rejected(reason: RejectReason.expired),
      onDismiss: () => dismissed++,
    );

    await tester.tap(find.text(ScanStrings.rejected));
    expect(dismissed, 0);
  });

  testWidgets('확인 실패는 오류 문구와 다시 스캔 안내를 보인다', (tester) async {
    await pump(tester, const Undetermined(message: '인터넷 연결을 확인해주세요.'));

    expect(find.text(ScanStrings.undetermined), findsOneWidget);
    expect(find.text('인터넷 연결을 확인해주세요.'), findsOneWidget);
    expect(find.text(ScanStrings.undeterminedGuide), findsOneWidget);
  });
}
