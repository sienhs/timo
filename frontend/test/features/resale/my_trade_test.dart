import 'package:flutter_test/flutter_test.dart';

import 'package:timo/features/resale/models/my_trade.dart';

/// 내 거래 내역은 판매·구매가 한 응답에 섞여 오고, 양도 목록 탭이 그중 무엇을
/// 세고 무엇에 취소 버튼을 달지 이 모델의 판정으로 정한다. 그 판정을 화면 없이
/// 확인한다.
void main() {
  /// 서버 `MyTradeSummaryResponseDto` 의 판매 한 건. 시안 화면의 값이다.
  Map<String, dynamic> saleJson({
    String status = 'LISTED',
    Object? startDate = '2026-09-14T12:04:00',
  }) => {
    'type': 'SALE',
    'tradeId': null,
    'listingId': 6,
    'status': status,
    'concertId': 1,
    'concertTitle': '2026 REMIND: 리센느',
    'posterImageUrl': null,
    'startDate': startDate,
    'venueName': '올림픽공원 KSPO DOME',
    'sectionName': 'R석',
    'grade': 'R',
    'seatNo': 12,
    'seatCol': 24,
    'price': 123000,
    'faceValue': 150000,
    'occurredAt': '2026-09-13T20:10:00',
  };

  group('내 거래 내역 항목', () {
    test('판매 항목을 읽는다. 체결 번호는 없다', () {
      final trade = MyTrade.fromJson(saleJson());

      expect(trade.type, MyTradeType.sale);
      expect(trade.isSale, isTrue);
      expect(trade.tradeId, isNull);
      expect(trade.listingId, 6);
      expect(trade.status, MyTradeStatus.listed);
      expect(trade.concertTitle, '2026 REMIND: 리센느');
      expect(trade.seatLabel, 'R석 12열 24번');
      expect(trade.price, 123000);
      expect(trade.faceValue, 150000);
      expect(trade.startAt, DateTime(2026, 9, 14, 12, 4));
      expect(trade.occurredAt, DateTime(2026, 9, 13, 20, 10));
      expect(trade.posterImageUrl, isNull);
    });

    test('구매 항목은 체결 번호와 체결 상태를 가진다', () {
      final trade = MyTrade.fromJson({
        ...saleJson(status: 'CONFIRMED'),
        'type': 'PURCHASE',
        'tradeId': 42,
      });

      expect(trade.type, MyTradeType.purchase);
      expect(trade.isSale, isFalse);
      expect(trade.tradeId, 42);
      expect(trade.status, MyTradeStatus.confirmed);
      // 산 티켓은 매물이 아니다. 양도 목록 탭이 세지 않는다.
      expect(trade.isOnSale, isFalse);
    });

    test('모르는 종류·상태는 unknown 으로 받고 깨지지 않는다', () {
      final trade = MyTrade.fromJson({
        ...saleJson(status: 'EXPIRED'),
        'type': 'GIFT',
      });

      expect(trade.type, MyTradeType.unknown);
      expect(trade.status, MyTradeStatus.unknown);
      expect(trade.isOnSale, isFalse);
    });
  });

  group('올라가 있는 매물 판정', () {
    test('판매 중인 매물만 참이다', () {
      expect(MyTrade.fromJson(saleJson()).isOnSale, isTrue);
      expect(MyTrade.fromJson(saleJson(status: 'SOLD')).isOnSale, isFalse);
      expect(MyTrade.fromJson(saleJson(status: 'CANCELED')).isOnSale, isFalse);
    });
  });

  group('양도 마감까지 남은 시간', () {
    // 공연 시작 2026-09-14 12:04.
    final trade = MyTrade.fromJson(saleJson());

    test('공연 시작 전이면 그때까지 센다', () {
      expect(
        trade.remaining(DateTime(2026, 9, 14, 4, 33)),
        const Duration(hours: 7, minutes: 31),
      );
    });

    test('공연이 시작했으면 null 이다', () {
      expect(trade.remaining(DateTime(2026, 9, 14, 12, 4)), isNull);
      expect(trade.remaining(DateTime(2026, 9, 15)), isNull);
    });

    test('날짜 미정이면 null 이다', () {
      final undecided = MyTrade.fromJson(saleJson(startDate: null));

      expect(undecided.startAt, isNull);
      expect(undecided.remaining(DateTime(2026, 9, 14)), isNull);
    });
  });
}
