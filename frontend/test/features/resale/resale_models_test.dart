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
    test('여는 시각부터 창이 끝날 때까지는 열려 있다', () {
      final opensAt = DateTime(2026, 5, 20, ResaleMetrics.marketOpensAtHour);
      final hours = MarketHours.at(opensAt.add(const Duration(minutes: 30)));

      expect(hours.isOpen, isTrue);
      expect(hours.nextBoundary, opensAt.add(ResaleMetrics.marketOpenDuration));
      expect(
        hours.remaining,
        ResaleMetrics.marketOpenDuration - const Duration(minutes: 30),
      );
    });

    test('여는 시각 전이면 닫혀 있고 그날 오픈까지 센다', () {
      final hours = MarketHours.at(DateTime(2026, 5, 20, 16, 37, 48));

      expect(hours.isOpen, isFalse);
      expect(
        hours.nextBoundary,
        DateTime(2026, 5, 20, ResaleMetrics.marketOpensAtHour),
      );
      expect(hours.remaining.inMinutes, 202);
    });

    test('창이 끝난 뒤면 다음 날 오픈까지 센다', () {
      final closedAt = DateTime(
        2026,
        5,
        20,
        ResaleMetrics.marketOpensAtHour,
      ).add(ResaleMetrics.marketOpenDuration);

      final hours = MarketHours.at(closedAt);

      expect(hours.isOpen, isFalse);
      // 자정을 넘겨 닫히는 창이라 '다음 오픈' 은 날짜가 바뀐 그날 저녁이다.
      expect(
        hours.nextBoundary,
        DateTime(
          closedAt.year,
          closedAt.month,
          closedAt.day,
          ResaleMetrics.marketOpensAtHour,
        ),
      );
    });

    test('여는 시각 표시는 두 자리로 맞춘다', () {
      expect(MarketHours.opensAtLabel, '20:00');
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
