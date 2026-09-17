package com.ssafy.timo.domain.reservation.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import com.ssafy.timo.domain.blockchain.TicketNftClient;
import com.ssafy.timo.domain.blockchain.TicketVaultClient;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.offer.service.CancelOfferService;
import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.reservation.exception.ReservationNotCancellableException;
import com.ssafy.timo.domain.reservation.repository.ReservationRepository;
import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.seat.repository.SeatHoldRepository;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.entity.TicketStatus;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import com.ssafy.timo.domain.transfer.entity.ListingStatus;
import com.ssafy.timo.domain.transfer.repository.TicketListingRepository;
import com.ssafy.timo.domain.transfer.repository.TicketTradeRepository;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.wallet.service.WalletService;
import com.ssafy.timo.global.storage.ImageStorage;
import java.math.BigInteger;
import java.time.Clock;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.test.util.ReflectionTestUtils;

/**
 * 예매 취소의 양도 가드를 목으로 본다.
 *
 * <p>통합 테스트({@code ReservationCancelGuardIntegrationTest})는 409 두 갈래만 볼 수 있다. 취소가
 * 성립하면 온체인 {@code revoke} 가 실제 RPC 를 부르기 때문이다. 여기서는 그 클라이언트를 목으로
 * 두고 <b>등록을 취소하고 나면 예매 취소가 다시 열리는지</b>, 그리고 막힐 때 온체인을 부르지 않는지 본다.
 */
@ExtendWith(MockitoExtension.class)
class ReservationCancelGuardTest {

    private static final Long MEMBER_ID = 7L;
    private static final Long ORGANIZER_ID = 99L;
    private static final Long RESERVATION_ID = 31L;
    private static final Long TICKET_ID = 41L;
    private static final Long CONCERT_ID = 51L;
    private static final Long SEAT_ID = 61L;
    private static final ZoneId ZONE = ZoneId.of("Asia/Seoul");
    private static final LocalDateTime NOW = LocalDateTime.of(2026, 9, 17, 21, 0);

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
    private CancelOfferService cancelOfferService;
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

    private ReservationServiceImpl service;
    private Ticket ticket;

    @BeforeEach
    void setUp() {
        service = new ReservationServiceImpl(memberRepository, concertRepository, seatHoldRepository,
                reservationRepository, ticketRepository, ticketTradeRepository, ticketListingRepository,
                cancelOfferService, walletService, ticketVaultClient, ticketNftClient, imageStorage, eventPublisher,
                Clock.fixed(NOW.atZone(ZONE).toInstant(), ZONE));

        ticket = ownedTicket();
        given(reservationRepository.findById(RESERVATION_ID)).willReturn(Optional.of(ticket.getReservation()));
        given(ticketRepository.findByReservationId(RESERVATION_ID)).willReturn(Optional.of(ticket));
    }

    @Test
    @DisplayName("양도된 티켓이면 409 이고 온체인 회수와 환불을 부르지 않는다")
    void rejectsTransferredTicketBeforeChain() {
        given(ticketTradeRepository.existsByTicketId(TICKET_ID)).willReturn(true);

        assertThatThrownBy(() -> service.cancel(MEMBER_ID, RESERVATION_ID))
                .isInstanceOf(ReservationNotCancellableException.class)
                .hasMessageContaining("양도된 티켓");
        verify(ticketNftClient, never()).revoke(any());
        verify(ticketVaultClient, never()).refund(anyString(), anyString(), any(), any());
        verify(cancelOfferService, never()).offerRevokedSeat(any(), any(), any(), any());
        assertThat(ticket.getStatus()).isEqualTo(TicketStatus.OWNED);
    }

    @Test
    @DisplayName("등록 중이면 409 이고 온체인을 부르지 않는다")
    void rejectsListedTicketBeforeChain() {
        given(ticketTradeRepository.existsByTicketId(TICKET_ID)).willReturn(false);
        given(ticketListingRepository.existsByTicketIdAndStatus(TICKET_ID, ListingStatus.LISTED)).willReturn(true);

        assertThatThrownBy(() -> service.cancel(MEMBER_ID, RESERVATION_ID))
                .isInstanceOf(ReservationNotCancellableException.class)
                .hasMessageContaining("등록 중");
        verify(ticketNftClient, never()).revoke(any());
    }

    @Test
    @DisplayName("등록을 취소했으면(거래 없음, LISTED 없음) 예매 취소가 다시 열려 회수까지 간다")
    void allowsCancelOnceListingIsClosed() {
        given(ticketTradeRepository.existsByTicketId(TICKET_ID)).willReturn(false);
        given(ticketListingRepository.existsByTicketIdAndStatus(TICKET_ID, ListingStatus.LISTED)).willReturn(false);
        given(walletService.getAddress(anyLong())).willReturn("0xabc");

        service.cancel(MEMBER_ID, RESERVATION_ID);

        verify(ticketNftClient).revoke(ticket.getTokenId());
        verify(ticketVaultClient).refund(anyString(), anyString(), any(), any());
        assertThat(ticket.getStatus()).isEqualTo(TicketStatus.REVOKED);
    }

    @Test
    @DisplayName("취소가 성립하면 회수한 자리로 취소표 추첨을 건다 - 취소자 본인은 제외 대상으로 넘긴다")
    void drawsCancelOfferAfterRevoke() {
        given(ticketTradeRepository.existsByTicketId(TICKET_ID)).willReturn(false);
        given(ticketListingRepository.existsByTicketIdAndStatus(TICKET_ID, ListingStatus.LISTED)).willReturn(false);
        given(walletService.getAddress(anyLong())).willReturn("0xabc");

        service.cancel(MEMBER_ID, RESERVATION_ID);

        verify(cancelOfferService).offerRevokedSeat(CONCERT_ID, SEAT_ID, RESERVATION_ID, MEMBER_ID);
    }

    /** 공연은 30일 뒤, 주최자와 좌석 정가까지 채워 컷오프와 환불 계산을 지나가게 한다. */
    private static Ticket ownedTicket() {
        Member member = Member.builder().phoneNumber("01012345678").name("정희성").nickname("희성").build();
        ReflectionTestUtils.setField(member, "id", MEMBER_ID);
        Member organizer = Member.builder().phoneNumber("01087654321").name("주최자").nickname("주최").build();
        ReflectionTestUtils.setField(organizer, "id", ORGANIZER_ID);

        Venue venue = Venue.builder().name("고척돔").address("서울").totalSeatCount(1).build();
        Concert concert = Concert.builder().title("취소 가드 공연").startDate(NOW.plusDays(30)).venue(venue).build();
        ReflectionTestUtils.setField(concert, "id", CONCERT_ID);
        concert.prepareForSale(organizer);
        Section section = Section.builder().name("A").price(100_000).rowCount(1).seatPerRow(1).build();
        Seat seat = Seat.builder().seatNo(1).seatCol(1).section(section).build();
        ReflectionTestUtils.setField(seat, "id", SEAT_ID);

        Reservation reservation = Reservation.builder().concert(concert).member(member).seat(seat).build();
        ReflectionTestUtils.setField(reservation, "id", RESERVATION_ID);

        Ticket ticket = Ticket.builder().reservation(reservation).build();
        ReflectionTestUtils.setField(ticket, "id", TICKET_ID);
        ticket.markMinted(BigInteger.valueOf(1), "0x" + "1".repeat(64));
        return ticket;
    }
}
