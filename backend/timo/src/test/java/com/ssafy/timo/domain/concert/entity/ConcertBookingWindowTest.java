package com.ssafy.timo.domain.concert.entity;

import com.ssafy.timo.domain.venue.entity.Venue;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.LocalDateTime;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * 예매 가능 시간 판정({@link Concert#bookingBlockReason})의 경계값.
 *
 * <p>구간은 {@code openAt <= now < startDate - 2h} 다. 양 끝의 포함·제외와, 사유가 겹칠 때
 * 상태 → 오픈 전 → 마감 후 순서로 앞의 것이 이기는지를 본다.
 */
class ConcertBookingWindowTest {

    private static final LocalDateTime OPEN_AT = LocalDateTime.of(2026, 9, 1, 20, 0);
    private static final LocalDateTime START_DATE = LocalDateTime.of(2026, 9, 20, 19, 30);
    private static final LocalDateTime CUTOFF = START_DATE.minusHours(Concert.BOOKING_CUTOFF_HOURS);

    @Test
    @DisplayName("오픈 1초 전이면 아직 열리지 않은 것이다")
    void notOpenOneSecondBeforeOpenAt() {
        Concert concert = onSale(OPEN_AT, START_DATE);

        assertThat(concert.bookingBlockReason(OPEN_AT.minusSeconds(1))).contains(BookingBlockReason.NOT_OPEN);
        assertThat(concert.isBookableAt(OPEN_AT.minusSeconds(1))).isFalse();
    }

    @Test
    @DisplayName("오픈 정각은 예매할 수 있다")
    void bookableExactlyAtOpenAt() {
        Concert concert = onSale(OPEN_AT, START_DATE);

        assertThat(concert.bookingBlockReason(OPEN_AT)).isEmpty();
        assertThat(concert.isBookableAt(OPEN_AT)).isTrue();
    }

    @Test
    @DisplayName("마감(공연 시작 2시간 전) 1초 전까지는 예매할 수 있다")
    void bookableOneSecondBeforeCutoff() {
        Concert concert = onSale(OPEN_AT, START_DATE);

        assertThat(concert.bookingBlockReason(CUTOFF.minusSeconds(1))).isEmpty();
        assertThat(concert.isBookableAt(CUTOFF.minusSeconds(1))).isTrue();
    }

    @Test
    @DisplayName("마감 정각은 이미 마감된 것이다")
    void closedExactlyAtCutoff() {
        Concert concert = onSale(OPEN_AT, START_DATE);

        assertThat(concert.bookingBlockReason(CUTOFF)).contains(BookingBlockReason.CLOSED);
        assertThat(concert.isBookableAt(CUTOFF)).isFalse();
    }

    @Test
    @DisplayName("시작 시각이 없는 ON_SALE 공연은 예매할 수 없다")
    void rejectsWhenStartDateIsNull() {
        Concert concert = onSale(OPEN_AT, null);

        assertThat(concert.bookingBlockReason(OPEN_AT.plusDays(1))).contains(BookingBlockReason.NOT_OPEN);
        assertThat(concert.isBookableAt(OPEN_AT.plusDays(1))).isFalse();
    }

    @Test
    @DisplayName("오픈 시각이 없는 ON_SALE 공연도 예매할 수 없다")
    void rejectsWhenOpenAtIsNull() {
        Concert concert = onSale(null, START_DATE);

        assertThat(concert.bookingBlockReason(CUTOFF.minusDays(1))).contains(BookingBlockReason.NOT_OPEN);
    }

    @Test
    @DisplayName("마감이 지났어도 상태가 ON_SALE 이 아니면 상태가 먼저 사유가 된다")
    void statusWinsOverClosedWindow() {
        Concert concert = withStatus(ConcertStatus.SOLD_OUT, OPEN_AT, START_DATE);

        assertThat(concert.bookingBlockReason(CUTOFF.plusMinutes(1))).contains(BookingBlockReason.NOT_ON_SALE);
    }

    @Test
    @DisplayName("시간 창 안이어도 상태가 ON_SALE 이 아니면 예매할 수 없다")
    void rejectsScheduledEvenInsideWindow() {
        Concert concert = withStatus(ConcertStatus.SCHEDULED, OPEN_AT, START_DATE);

        assertThat(concert.bookingBlockReason(OPEN_AT.plusDays(1))).contains(BookingBlockReason.NOT_ON_SALE);
    }

    private static Concert onSale(LocalDateTime openAt, LocalDateTime startDate) {
        return withStatus(ConcertStatus.ON_SALE, openAt, startDate);
    }

    /** 갓 만든 공연은 늘 SCHEDULED 라 상태 전이 수단이 없다. 통합 테스트와 같은 방식으로 리플렉션으로 덮는다. */
    private static Concert withStatus(ConcertStatus status, LocalDateTime openAt, LocalDateTime startDate) {
        Venue venue = Venue.builder().name("고척돔").address("서울").totalSeatCount(1).build();
        Concert concert = Concert.builder()
                .title("예매 창 공연")
                .genre(ConcertGenre.CONCERT)
                .ageRating(AgeRating.ALL)
                .openAt(openAt)
                .startDate(startDate)
                .endDate(startDate == null ? null : startDate.plusHours(2))
                .venue(venue)
                .build();
        ReflectionTestUtils.setField(concert, "status", status);
        return concert;
    }
}
