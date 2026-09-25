package com.ssafy.timo.domain.seat.service;

import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.entity.ConcertStatus;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.reservation.exception.BookingClosedException;
import com.ssafy.timo.domain.reservation.exception.BookingNotOpenException;
import com.ssafy.timo.domain.reservation.exception.ConcertNotOnSaleException;
import com.ssafy.timo.domain.reservation.exception.ReservationErrorCode;
import com.ssafy.timo.domain.reservation.repository.ReservationRepository;
import com.ssafy.timo.domain.seat.dto.SeatHoldResponseDto;
import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.SeatHold;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.seat.repository.SeatHoldRepository;
import com.ssafy.timo.domain.seat.repository.SeatRepository;
import com.ssafy.timo.domain.seat.repository.SectionRepository;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.global.exception.BusinessException;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.Clock;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.then;
import static org.mockito.Mockito.never;

/**
 * 선점({@link SeatServiceImpl#hold})의 예매 가능 시간 판정을 시계를 고정해 본다.
 *
 * <p>통합 테스트는 컨텍스트를 공유하는 규약 때문에 {@code Clock} 빈을 갈아 끼울 수 없다. 여기서는
 * 서비스를 직접 만들어 {@link Clock#fixed} 를 넣고 오픈·마감 경계의 1초 차이를 본다.
 */
@ExtendWith(MockitoExtension.class)
class SeatHoldBookingWindowTest {

    private static final Long MEMBER_ID = 7L;
    private static final Long CONCERT_ID = 3L;
    private static final Long SEAT_ID = 55L;
    private static final Long VENUE_ID = 10L;
    private static final ZoneId ZONE = ZoneId.of("Asia/Seoul");

    private static final LocalDateTime OPEN_AT = LocalDateTime.of(2026, 9, 1, 20, 0);
    private static final LocalDateTime START_DATE = LocalDateTime.of(2026, 9, 20, 19, 30);
    private static final LocalDateTime CUTOFF = START_DATE.minusMinutes(Concert.BOOKING_CUTOFF_MINUTES);

    @Mock
    private SectionRepository sectionRepository;
    @Mock
    private SeatRepository seatRepository;
    @Mock
    private SeatHoldRepository seatHoldRepository;
    @Mock
    private ReservationRepository reservationRepository;

    @Mock
    private VenueRepository venueRepository;
    @Mock
    private ConcertRepository concertRepository;
    @Mock
    private MemberRepository memberRepository;

    @Test
    @DisplayName("오픈 1초 전 선점은 BOOKING_NOT_OPEN 으로 거절되고 선점 행을 만들지 않는다")
    void rejectsOneSecondBeforeOpenAt() {
        givenConcert(ConcertStatus.ON_SALE, OPEN_AT, START_DATE);

        assertThatThrownBy(() -> serviceAt(OPEN_AT.minusSeconds(1)).hold(MEMBER_ID, CONCERT_ID, SEAT_ID))
                .isInstanceOf(BookingNotOpenException.class)
                .extracting(e -> ((BusinessException) e).getErrorCode())
                .isEqualTo(ReservationErrorCode.BOOKING_NOT_OPEN);

        then(seatHoldRepository).should(never()).saveAndFlush(any(SeatHold.class));
    }

    @Test
    @DisplayName("오픈 정각 선점은 성공한다")
    void holdsExactlyAtOpenAt() {
        givenConcert(ConcertStatus.ON_SALE, OPEN_AT, START_DATE);
        givenSeatInConcertVenue();

        SeatHoldResponseDto response = serviceAt(OPEN_AT).hold(MEMBER_ID, CONCERT_ID, SEAT_ID);

        assertThat(response.expiresAt()).isEqualTo(OPEN_AT.plusMinutes(5));
        then(seatHoldRepository).should().saveAndFlush(any(SeatHold.class));
    }

    @Test
    @DisplayName("마감 1초 전 선점은 성공한다")
    void holdsOneSecondBeforeCutoff() {
        givenConcert(ConcertStatus.ON_SALE, OPEN_AT, START_DATE);
        givenSeatInConcertVenue();

        SeatHoldResponseDto response = serviceAt(CUTOFF.minusSeconds(1)).hold(MEMBER_ID, CONCERT_ID, SEAT_ID);

        assertThat(response.expiresAt()).isEqualTo(CUTOFF.minusSeconds(1).plusMinutes(5));
        then(seatHoldRepository).should().saveAndFlush(any(SeatHold.class));
    }

    @Test
    @DisplayName("마감 정각 선점은 BOOKING_CLOSED 로 거절된다")
    void rejectsExactlyAtCutoff() {
        givenConcert(ConcertStatus.ON_SALE, OPEN_AT, START_DATE);

        assertThatThrownBy(() -> serviceAt(CUTOFF).hold(MEMBER_ID, CONCERT_ID, SEAT_ID))
                .isInstanceOf(BookingClosedException.class)
                .extracting(e -> ((BusinessException) e).getErrorCode())
                .isEqualTo(ReservationErrorCode.BOOKING_CLOSED);

        then(seatHoldRepository).should(never()).saveAndFlush(any(SeatHold.class));
    }

    @Test
    @DisplayName("시작 시각이 없는 ON_SALE 공연은 선점할 수 없다")
    void rejectsWhenStartDateIsNull() {
        givenConcert(ConcertStatus.ON_SALE, OPEN_AT, null);

        assertThatThrownBy(() -> serviceAt(OPEN_AT.plusDays(1)).hold(MEMBER_ID, CONCERT_ID, SEAT_ID))
                .isInstanceOf(BookingNotOpenException.class);

        then(seatHoldRepository).should(never()).saveAndFlush(any(SeatHold.class));
    }

    @Test
    @DisplayName("마감이 지났어도 매진 공연은 상태 검사가 먼저라 CONCERT_NOT_ON_SALE 이다")
    void statusIsCheckedBeforeWindow() {
        givenConcert(ConcertStatus.SOLD_OUT, OPEN_AT, START_DATE);

        assertThatThrownBy(() -> serviceAt(CUTOFF.plusMinutes(1)).hold(MEMBER_ID, CONCERT_ID, SEAT_ID))
                .isInstanceOf(ConcertNotOnSaleException.class)
                .extracting(e -> ((BusinessException) e).getErrorCode())
                .isEqualTo(ReservationErrorCode.CONCERT_NOT_ON_SALE);
    }

    private SeatServiceImpl serviceAt(LocalDateTime now) {
        return new SeatServiceImpl(sectionRepository, seatRepository, seatHoldRepository, reservationRepository,
                venueRepository, concertRepository, memberRepository,
                Clock.fixed(now.atZone(ZONE).toInstant(), ZONE));
    }

    private void givenConcert(ConcertStatus status, LocalDateTime openAt, LocalDateTime startDate) {
        Concert concert = Concert.builder()
                .title("선점 창 공연")
                .genre(ConcertGenre.CONCERT)
                .ageRating(AgeRating.ALL)
                .openAt(openAt)
                .startDate(startDate)
                .endDate(startDate == null ? null : startDate.plusHours(2))
                .venue(venue())
                .build();
        ReflectionTestUtils.setField(concert, "id", CONCERT_ID);
        ReflectionTestUtils.setField(concert, "status", status);
        given(concertRepository.findById(CONCERT_ID)).willReturn(Optional.of(concert));
    }

    /** 선점 성공 경로에 필요한 최소 좌석. 공연장이 공연과 같아야 소속 검사를 통과한다. */
    private void givenSeatInConcertVenue() {
        Section section = Section.builder().name("A").price(100_000).rowCount(1).seatPerRow(1).venue(venue()).build();
        Seat seat = Seat.builder().seatNo(1).seatCol(1).section(section).build();
        ReflectionTestUtils.setField(seat, "id", SEAT_ID);
        given(seatRepository.findById(SEAT_ID)).willReturn(Optional.of(seat));
    }

    private static Venue venue() {
        Venue venue = Venue.builder().name("고척돔").address("서울").totalSeatCount(1).build();
        ReflectionTestUtils.setField(venue, "id", VENUE_ID);
        return venue;
    }
}
