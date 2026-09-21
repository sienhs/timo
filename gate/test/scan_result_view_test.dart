import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo_gate/core/theme/app_theme.dart';
import 'package:timo_gate/core/utils/formatters.dart';
import 'package:timo_gate/features/scan/constants.dart';
import 'package:timo_gate/features/scan/models/verification_result.dart';
import 'package:timo_gate/features/scan/widgets/scan_result_view.dart';

void main() {
  final verifiedAt = DateTime(2026, 9, 21, 19, 2, 14);

  Future<void> pump(
    WidgetTester tester,
    VerificationResult result, {
    VoidCallback? onDismiss,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: ScanResultView(
        result: result,
        verifiedAt: verifiedAt,
        onDismiss: onDismiss ?? () {},
      ),
    ),
  );

  testWidgets('입장 허용은 확인 뱃지를 보이고 아무 데나 눌러도 닫힌다', (tester) async {
    var dismissed = 0;
    await pump(tester, const Admitted(), onDismiss: () => dismissed++);

    expect(find.text(ScanStrings.admitted), findsOneWidget);
    expect(find.text(ScanStrings.admittedPill), findsOneWidget);

    await tester.tap(find.text(ScanStrings.admitted));
    expect(dismissed, 1);
  });

  testWidgets('결과 카드는 검표 완료 시각을 초까지 적는다', (tester) async {
    await pump(tester, const Admitted());

    expect(find.text(ScanStrings.verifiedAt), findsOneWidget);
    expect(
      find.text(ScanStrings.verifiedAtValue(formatClock(verifiedAt))),
      findsOneWidget,
    );
  });

  testWidgets('거절은 사유·안내를 보이고 버튼 하나로 닫힌다', (tester) async {
    var dismissed = 0;
    await pump(
      tester,
      const Rejected(reason: RejectReason.alreadyUsed),
      onDismiss: () => dismissed++,
    );

    expect(find.text(ScanStrings.rejected), findsOneWidget);
    expect(find.text(RejectReason.alreadyUsed.label), findsOneWidget);
    expect(find.text(ScanStrings.rejectedGuide), findsOneWidget);
    expect(find.text(ScanStrings.confirm), findsOneWidget);

    await tester.tap(find.text(ScanStrings.confirm));
    expect(dismissed, 1);
  });

  testWidgets('중복 스캔 뱃지는 이미 입장한 티켓에만 붙는다', (tester) async {
    await pump(tester, const Rejected(reason: RejectReason.alreadyUsed));
    expect(find.text(ScanStrings.duplicatePill), findsOneWidget);

    await pump(tester, const Rejected(reason: RejectReason.expired));
    expect(find.text(ScanStrings.duplicatePill), findsNothing);
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
