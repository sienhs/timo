import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timo/core/utils/amount_input_formatter.dart';
import 'package:timo/features/mypage/data/mock_my_page_data.dart';
import 'package:timo/features/mypage/data/mock_wallet_ledger.dart';
import 'package:timo/features/mypage/models/charge_amount.dart';

void main() {
  group('ChargeAmount', () {
    test('입력칸 글자에서 숫자만 읽는다', () {
      expect(ChargeAmount.parse('10,000').value, 10000);
      expect(ChargeAmount.parse('').value, 0);
      expect(ChargeAmount.parse('MSR').value, 0);
    });

    test('비었거나 한도 밖이면 보낼 수 없다', () {
      expect(const ChargeAmount.empty().canSubmit, isFalse);
      expect(const ChargeAmount(ChargeAmount.min - 1).canSubmit, isFalse);
      expect(const ChargeAmount(ChargeAmount.min).canSubmit, isTrue);
      expect(const ChargeAmount(ChargeAmount.max).canSubmit, isTrue);
      expect(const ChargeAmount(ChargeAmount.max + 1).canSubmit, isFalse);
    });

    test('빈 칸은 나무라지 않고, 한도 밖일 때만 문구가 나온다', () {
      expect(const ChargeAmount.empty().errorMessage, isNull);
      expect(const ChargeAmount(10000).errorMessage, isNull);
      expect(const ChargeAmount(500).errorMessage, contains('최소'));
      expect(const ChargeAmount(9999999).errorMessage, contains('최대'));
    });
  });

  group('AmountInputFormatter', () {
    const formatter = AmountInputFormatter(maxDigits: ChargeAmount.maxDigits);

    /// 빈 칸에서 [text] 를 친 결과.
    String typed(String text, {String from = ''}) => formatter
        .formatEditUpdate(
          TextEditingValue(text: from),
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          ),
        )
        .text;

    test('숫자만 남기고 천 단위 쉼표를 붙인다', () {
      expect(typed('10000'), '10,000');
      expect(typed('abc1000!'), '1,000');
      expect(typed('007'), '7');
    });

    test('다 지우면 빈 칸이 된다. 지울 수 없는 0 을 남기지 않는다', () {
      expect(typed('', from: '5'), '');
    });

    test('한도 자릿수까지만 받는다', () {
      expect(typed('123456789'), '1,234,567');
    });

    test('쉼표만 지우면 숫자 하나가 지워진다(아무 일도 없어 보이지 않게)', () {
      expect(typed('10000', from: '10,000'), '1,000');
    });

    test('커서는 늘 끝에 둔다', () {
      final value = formatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(
          text: '10000',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      expect(value.selection.baseOffset, value.text.length);
    });
  });

  group('MockWalletLedger', () {
    test('충전분이 잔액에 더해지고 내역 맨 앞에 한 줄이 생긴다', () {
      final at = DateTime(2026, 9, 15, 10, 30);
      final ledger = MockWalletLedger(clock: () => at);
      final before = MockMyPageData.wallet;

      final wallet = ledger.charge(10000);

      expect(wallet.balance, before.balance + 10000);
      expect(wallet.transactions.length, before.transactions.length + 1);

      final charged = wallet.transactions.first;
      expect(charged.title, MockMyPageData.chargeTitle);
      expect(charged.source, MockMyPageData.chargeSource);
      expect(charged.amount, 10000);
      expect(charged.balanceAfter, wallet.balance);
      expect(charged.occurredAt, at);
      expect(charged.isCredit, isTrue);
    });

    test('충전이 쌓인다. 다음 조회에도 남아 있다', () {
      final ledger = MockWalletLedger();
      final start = ledger.wallet.balance;

      ledger.charge(5000);
      ledger.charge(30000);

      expect(ledger.wallet.balance, start + 35000);
      expect(ledger.wallet.transactions.first.amount, 30000);
    });

    test('원장마다 따로 센다. 공용 목 데이터는 그대로다', () {
      final balance = MockMyPageData.wallet.balance;
      MockWalletLedger().charge(150000);

      expect(MockMyPageData.wallet.balance, balance);
      expect(MockWalletLedger().wallet.balance, balance);
    });
  });
}
