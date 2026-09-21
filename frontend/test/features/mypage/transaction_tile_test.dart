import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timo/core/theme/app_theme.dart';
import 'package:timo/core/utils/formatters.dart';
import 'package:timo/features/mypage/constants.dart';
import 'package:timo/features/mypage/models/wallet_transaction.dart';
import 'package:timo/features/mypage/widgets/transaction_tile.dart';

void main() {
  Future<void> pumpTile(WidgetTester tester, WalletTransaction transaction) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: TransactionTile(transaction: transaction)),
      ),
    );
  }

  WalletTransaction transactionFrom(String source) => WalletTransaction(
    title: '버섯 충전',
    amount: 30000,
    balanceAfter: 153000,
    occurredAt: DateTime(2026, 9, 21, 14, 30),
    source: source,
  );

  final when = formatMonthDayClock(DateTime(2026, 9, 21, 14, 30));

  group('TransactionTile 의 출처', () {
    testWidgets('모의 결제는 화면에서 모의를 떼고 보여 준다', (tester) async {
      await pumpTile(tester, transactionFrom(MyPageStrings.mockPgSource));

      expect(find.text('$when · PG 결제'), findsOneWidget);
      expect(find.textContaining('모의'), findsNothing);
    });

    testWidgets('다른 출처는 서버가 준 대로 보여 준다', (tester) async {
      await pumpTile(tester, transactionFrom('양도 마켓'));

      expect(find.text('$when · 양도 마켓'), findsOneWidget);
    });
  });
}
