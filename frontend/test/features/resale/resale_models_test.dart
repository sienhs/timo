import 'package:flutter_test/flutter_test.dart';

import 'package:timo/features/resale/constants.dart';
import 'package:timo/features/resale/models/listing.dart';
import 'package:timo/features/resale/models/listing_price.dart';
import 'package:timo/features/resale/models/market_concert.dart';
import 'package:timo/features/resale/models/market_hours.dart';
import 'package:timo/features/resale/models/market_sort.dart';

/// 마켓 운영 시간·판매가 판정·정렬은 화면 없이 확인한다. 셋 다 화면이 무엇을
/// 보여 줄지 정하는 규칙이라, 규칙이 어긋나면 화면 테스트가 엉뚱한 곳에서
/// 깨진다.
void main() {
  group('마켓 운영 시간', () {
    /// 응답을 받은 기기 시각. 서버 시각과 같다고 두고, 시차가 있는 경우만 따로 준다.
    final received = DateTime(2026, 9, 17, 21, 25, 17);

    /// 서버 `GET /market/hours` 응답. 실제 응답 예시의 값이다.
    MarketHours hoursOf({
      required bool open,
      required String serverTime,
      DateTime? receivedAt,
    }) => MarketHours.fromJson({
      'open': open,
      'serverTime': serverTime,
      'opensAt': '2026-09-17T20:00:00',
      'closesAt': '2026-09-17T23:59:59',
    }, receivedAt: receivedAt ?? received);

    test('서버 응답을 읽고 여는 시각을 두 자리로 적는다', () {
      final hours = hoursOf(open: true, serverTime: '2026-09-17T21:25:17');

      expect(hours.isOpen, isTrue);
      expect(hours.serverTime, DateTime(2026, 9, 17, 21, 25, 17));
      expect(hours.opensAt, DateTime(2026, 9, 17, 20));
      expect(hours.closesAt, DateTime(2026, 9, 17, 23, 59, 59));
      expect(hours.receivedAt, received);
      expect(hours.opensAtLabel, '20:00');
    });

    test('열려 있으면 닫히는 순간(closesAt 1초 뒤)까지 센다', () {
      final hours = hoursOf(open: true, serverTime: '2026-09-17T21:25:17');

      expect(hours.nextBoundary, DateTime(2026, 9, 18));
      expect(
        hours.remainingAt(received),
        const Duration(hours: 2, minutes: 34, seconds: 43),
      );
    });

    test('닫혀 있으면 다음 오픈까지 센다', () {
      final hours = hoursOf(open: false, serverTime: '2026-09-17T16:37:00');

      expect(hours.nextBoundary, DateTime(2026, 9, 17, 20));
      expect(
        hours.remainingAt(received),
        const Duration(hours: 3, minutes: 23),
      );
    });

    test('남은 시간은 기기 시계가 아니라 서버 시계로 센다', () {
      // 기기 시계가 서버보다 10분 빠르다.
      final deviceAtReceipt = received.add(const Duration(minutes: 10));
      final hours = hoursOf(
        open: true,
        serverTime: '2026-09-17T21:25:17',
        receivedAt: deviceAtReceipt,
      );

      expect(
        hours.serverNow(deviceAtReceipt),
        DateTime(2026, 9, 17, 21, 25, 17),
      );
      // 기기에서 1분이 흐르면 서버에서도 1분이 흐른다.
      final aMinuteLater = deviceAtReceipt.add(const Duration(minutes: 1));
      expect(hours.serverNow(aMinuteLater), DateTime(2026, 9, 17, 21, 26, 17));
      expect(
        hours.remainingAt(aMinuteLater),
        const Duration(hours: 2, minutes: 33, seconds: 43),
      );
    });

    test('경계를 지났으면 0 이다', () {
      final hours = hoursOf(open: false, serverTime: '2026-09-17T19:59:59');

      expect(
        hours.remainingAt(received.add(const Duration(seconds: 5))),
        Duration.zero,
      );
    });

    test('매물은 등록 다음 날 여는 시각에 올라간다', () {
      final hours = hoursOf(open: true, serverTime: '2026-09-17T21:25:17');

      expect(
        hours.visibleFrom(DateTime(2026, 9, 17, 21, 30)),
        DateTime(2026, 9, 18, 20),
      );
      // 월말도 날짜가 넘어간다.
      expect(
        hours.visibleFrom(DateTime(2026, 9, 30, 3)),
        DateTime(2026, 10, 1, 20),
      );
    });

    test('오늘 등록한 매물은 아직 안 보이고, 어제 등록한 매물은 보인다', () {
      final hours = hoursOf(open: true, serverTime: '2026-09-17T21:25:17');

      expect(
        hours.isListingVisible(DateTime(2026, 9, 17, 0, 0), received),
        isFalse,
      );
      expect(
        hours.isListingVisible(DateTime(2026, 9, 16, 23, 59), received),
        isTrue,
      );
    });

    test('보이는지는 기기 날짜가 아니라 서버 날짜로 가른다', () {
      // 서버는 아직 9월 17일 23:30 인데 기기 시계는 이미 18일 00:30 이다.
      final deviceAtReceipt = DateTime(2026, 9, 18, 0, 30);
      final hours = hoursOf(
        open: true,
        serverTime: '2026-09-17T23:30:00',
        receivedAt: deviceAtReceipt,
      );

      // 17일에 등록한 매물은 서버 기준 아직 오늘 것이라 안 보인다.
      expect(
        hours.isListingVisible(DateTime(2026, 9, 17, 10), deviceAtReceipt),
        isFalse,
      );
    });
  });

  group('판매가', () {
    ListingPrice priceOf(String text) =>
        ListingPrice.parse(text, faceValue: 198600);

    test('정가와 같으면 등록할 수 있다', () {
      expect(priceOf('198,600').canSubmit, isTrue);
      expect(priceOf('198,600').errorMessage, isNull);
    });

    test('정가를 넘기면 등록할 수 없고 이유를 말한다', () {
      final price = priceOf('200,000');

      expect(price.canSubmit, isFalse);
      expect(price.errorMessage, ResaleStrings.priceOverFace);
      // 넘긴 값도 슬라이더에서는 끝까지 간 것으로 본다.
      expect(price.ratio, 1);
    });

    test('빈 칸은 등록할 수 없지만 나무라지는 않는다', () {
      final price = priceOf('');

      expect(price.canSubmit, isFalse);
      expect(price.errorMessage, isNull);
      expect(price.ratio, 0);
    });
  });

  group('정렬', () {
    MarketConcert concertOf({
      required int id,
      required int listingCount,
      required int daysLater,
    }) => MarketConcert(
      concertId: id,
      title: '공연 $id',
      venueName: '공연장',
      listingCount: listingCount,
      lowestPrice: 10000,
      startAt: DateTime(2026, 5, 20).add(Duration(days: daysLater)),
    );

    Listing listingOf({
      required int id,
      required int price,
      required int minutesAgo,
    }) => Listing(
      listingId: id,
      sectionName: 'R석',
      price: price,
      faceValue: 200000,
      discountRate: 0,
      mine: false,
      listedAt: DateTime(2026, 5, 20).subtract(Duration(minutes: minutesAgo)),
    );

    test('인기순은 매물이 많은 공연부터, 같으면 임박한 공연부터', () {
      final concerts = [
        concertOf(id: 1, listingCount: 1, daysLater: 1),
        concertOf(id: 2, listingCount: 4, daysLater: 9),
        concertOf(id: 3, listingCount: 4, daysLater: 3),
      ];

      expect(ConcertSort.popular.sorted(concerts).map((c) => c.concertId), [
        3,
        2,
        1,
      ]);
    });

    test('마감임박순은 공연 날짜 순이고 원본을 뒤집지 않는다', () {
      final concerts = [
        concertOf(id: 1, listingCount: 1, daysLater: 9),
        concertOf(id: 2, listingCount: 4, daysLater: 1),
      ];

      expect(ConcertSort.deadline.sorted(concerts).map((c) => c.concertId), [
        2,
        1,
      ]);
      expect(concerts.map((c) => c.concertId), [1, 2]);
    });

    test('매물은 최신등록순·낮은가격순으로 갈린다', () {
      final listings = [
        listingOf(id: 1, price: 176000, minutesAgo: 10),
        listingOf(id: 2, price: 150000, minutesAgo: 120),
      ];

      expect(ListingSort.latest.sorted(listings).first.listingId, 1);
      expect(ListingSort.lowestPrice.sorted(listings).first.listingId, 2);
    });
  });
}
