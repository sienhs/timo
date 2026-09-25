package com.ssafy.timo.domain.reservation.service;

import com.ssafy.timo.domain.blockchain.TicketNftClient;
import com.ssafy.timo.domain.blockchain.TicketVaultClient;
import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.entity.ConcertStatus;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.reservation.dto.CreateReservationRequestDto;
import com.ssafy.timo.domain.reservation.dto.ReservationDetailResponseDto;
import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.reservation.exception.BookingClosedException;
import com.ssafy.timo.domain.reservation.exception.ConcertNotOnSaleException;
import com.ssafy.timo.domain.reservation.exception.ReservationErrorCode;
import com.ssafy.timo.domain.reservation.repository.ReservationRepository;
import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.SeatHold;
import com.ssafy.timo.domain.seat.entity.SeatHoldStatus;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.seat.repository.SeatHoldRepository;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import com.ssafy.timo.domain.transfer.repository.TicketListingRepository;
import com.ssafy.timo.domain.transfer.repository.TicketTradeRepository;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.wallet.service.WalletService;
import com.ssafy.timo.global.exception.BusinessException;
import com.ssafy.timo.global.storage.ImageStorage;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigInteger;
import java.time.Clock;
import java.util.Random;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.then;
import static org.mockito.Mockito.never;

/**
 * 결제({@link ReservationServiceImpl#create})의 예매 가능 시간 판정을 시계를 고정해 본다.
 *
 * <p>핵심은 <b>선점은 마감 전에 됐는데 결제가 마감 후인 경우</b>다. 선점은 5분 유효하므로 마감 직전에
 * 잡은 자리는 마감을 넘겨서도 살아 있다 - 그 자리로 결제를 시도하면 선점이 유효해도 막혀야 한다.
 */
@ExtendWith(MockitoExtension.class)
class ReservationCreateBookingWindowTest {

    private static final Long MEMBER_ID = 7L;
    private static final Long ORGANIZER_ID = 99L;
    private static final Long CONCERT_ID = 3L;
    private static final Long SEAT_ID = 55L;
    private static final ZoneId ZONE = ZoneId.of("Asia/Seoul");

    private static final LocalDateTime OPEN_AT = LocalDateTime.of(2026, 9, 1, 20, 0);
    private static final LocalDateTime START_DATE = LocalDateTime.of(2026, 9, 20, 19, 30);
    private static final LocalDateTime CUTOFF = START_DATE.minusMinutes(Concert.BOOKING_CUTOFF_MINUTES);

    @Mock
    private MemberRepository memberRepository;
    @Mock
    private ConcertRepository concertRepository;
    @Mock
    private SeatHoldRepository seatHoldRepository;
    @Mock
    private ReservationRepository reservationRepository;
    @Mock
    private TicketRepository ticketRepository;
    @Mock
    private TicketTradeRepository ticketTradeRepository;
    @Mock
    private TicketListingRepository ticketListingRepository;
    @Mock
    private WalletService walletService;
    @Mock
    private TicketVaultClient ticketVaultClient;
    @Mock
    private TicketNftClient ticketNftClient;
    @Mock
    private ImageStorage imageStorage;
    @Mock
    private ApplicationEventPublisher eventPublisher;

    @Test
    @DisplayName("마감 1분 전에 잡은 선점이 살아 있어도 마감 1초 후 결제는 BOOKING_CLOSED 다")
    void rejectsPaymentAfterCutoffEvenIfHoldIsStillActive() {
        Concert concert = givenConcert(ConcertStatus.ON_SALE, OPEN_AT, START_DATE);
        SeatHold hold = heldAt(concert, CUTOFF.minusMinutes(1));
        assertThat(hold.isActiveAt(CUTOFF.plusSeconds(1))).isTrue();

        assertThatThrownBy(() -> serviceAt(CUTOFF.plusSeconds(1)).create(MEMBER_ID, request()))
                .isInstanceOf(BookingClosedException.class)
                .extracting(e -> ((BusinessException) e).getErrorCode())
                .isEqualTo(ReservationErrorCode.BOOKING_CLOSED);

        then(seatHoldRepository).should(never()).findActive(anyLong(), anyLong(), any());
        then(reservationRepository).should(never()).save(any(Reservation.class));
        assertThat(hold.getStatus()).isEqualTo(SeatHoldStatus.HELD);
    }

    @Test
    @DisplayName("마감 1초 전 결제는 선점을 주문으로 바꾼다")
    void createsOneSecondBeforeCutoff() {
        Concert concert = givenConcert(ConcertStatus.ON_SALE, OPEN_AT, START_DATE);
        SeatHold hold = heldAt(concert, CUTOFF.minusMinutes(1));
        LocalDateTime now = CUTOFF.minusSeconds(1);
        given(seatHoldRepository.findActive(CONCERT_ID, SEAT_ID, now)).willReturn(Optional.of(hold));
        given(memberRepository.findById(MEMBER_ID)).willReturn(Optional.of(hold.getMember()));
        given(reservationRepository.save(any(Reservation.class))).willAnswer(inv -> inv.getArgument(0));
        given(ticketRepository.save(any(Ticket.class))).willAnswer(inv -> inv.getArgument(0));

        ReservationDetailResponseDto response = serviceAt(now).create(MEMBER_ID, request());

        assertThat(response.concertId()).isEqualTo(CONCERT_ID);
        assertThat(response.seatId()).isEqualTo(SEAT_ID);
        assertThat(hold.getStatus()).isEqualTo(SeatHoldStatus.CONVERTED);
    }

    @Test
    @DisplayName("마감이 지났어도 매진 공연은 상태 검사가 먼저라 CONCERT_NOT_ON_SALE 이다")
    void statusIsCheckedBeforeWindow() {
        givenConcert(ConcertStatus.SOLD_OUT, OPEN_AT, START_DATE);

        assertThatThrownBy(() -> serviceAt(CUTOFF.plusMinutes(1)).create(MEMBER_ID, request()))
                .isInstanceOf(ConcertNotOnSaleException.class)
                .extracting(e -> ((BusinessException) e).getErrorCode())
                .isEqualTo(ReservationErrorCode.CONCERT_NOT_ON_SALE);

        then(reservationRepository).should(never()).save(any(Reservation.class));
    }

    private ReservationServiceImpl serviceAt(LocalDateTime now) {
        return new ReservationServiceImpl(memberRepository, concertRepository, seatHoldRepository,
                reservationRepository, ticketRepository, ticketTradeRepository, ticketListingRepository,
                walletService, ticketVaultClient, ticketNftClient, imageStorage, eventPublisher,
                new Random(0), Clock.fixed(now.atZone(ZONE).toInstant(), ZONE));
    }

    private static CreateReservationRequestDto request() {
        return new CreateReservationRequestDto(CONCERT_ID, SEAT_ID);
    }

    /** 주최자·showId 까지 채워 {@code isReadyForBooking()} 불변식을 통과시킨다 - 여기서 보는 건 시간 창뿐이다. */
    private Concert givenConcert(ConcertStatus status, LocalDateTime openAt, LocalDateTime startDate) {
        Venue venue = Venue.builder().name("고척돔").address("서울").totalSeatCount(1).build();
        Concert concert = Concert.builder()
                .title("결제 창 공연")
                .genre(ConcertGenre.CONCERT)
                .ageRating(AgeRating.ALL)
                .openAt(openAt)
                .startDate(startDate)
                .endDate(startDate.plusHours(2))
                .venue(venue)
                .build();
        ReflectionTestUtils.setField(concert, "id", CONCERT_ID);
        ReflectionTestUtils.setField(concert, "status", status);

        Member organizer = Member.builder().phoneNumber("01087654321").name("주최자").nickname("주최").build();
        ReflectionTestUtils.setField(organizer, "id", ORGANIZER_ID);
        concert.prepareForSale(organizer);
        concert.confirmRegistered(BigInteger.ONE);

        given(concertRepository.findById(CONCERT_ID)).willReturn(Optional.of(concert));
        return concert;
    }

    /** {@code heldAt} 시점에 잡은 선점. 실제 규약대로 5분 뒤 만료다. */
    private static SeatHold heldAt(Concert concert, LocalDateTime heldAt) {
        Member member = Member.builder().phoneNumber("01012345678").name("정희성").nickname("희성").build();
        ReflectionTestUtils.setField(member, "id", MEMBER_ID);
        Section section = Section.builder().name("A").price(100_000).rowCount(1).seatPerRow(1).build();
        Seat seat = Seat.builder().seatNo(1).seatCol(1).section(section).build();
        ReflectionTestUtils.setField(seat, "id", SEAT_ID);

        return SeatHold.builder()
                .concert(concert)
                .seat(seat)
                .member(member)
                .expiresAt(heldAt.plusMinutes(5))
                .build();
    }
}
