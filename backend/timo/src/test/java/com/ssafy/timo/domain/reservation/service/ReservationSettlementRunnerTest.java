package com.ssafy.timo.domain.reservation.service;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.willDoNothing;
import static org.mockito.BDDMockito.willThrow;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

import com.ssafy.timo.domain.blockchain.ContractCallException;
import com.ssafy.timo.domain.blockchain.ContractRevertException;
import com.ssafy.timo.domain.blockchain.MintResult;
import com.ssafy.timo.domain.blockchain.TicketNftClient;
import com.ssafy.timo.domain.blockchain.TicketVaultClient;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.reservation.repository.ReservationRepository;
import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.seat.repository.SectionRepository;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import com.ssafy.timo.domain.wallet.service.WalletService;

import java.math.BigInteger;
import java.time.Clock;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 온체인 호출의 revert 와 일시적 실패(재시도 대상)를 구분해 처리하는지 본다.
 *
 * <p>revert 는 곧바로 보상으로, 그 외는 {@code MAX_ATTEMPTS} 번까지 재시도 후에만 보상으로 간다.
 */
@ExtendWith(MockitoExtension.class)
class ReservationSettlementRunnerTest {

    private static final Long RESERVATION_ID = 100L;
    private static final Long MEMBER_ID = 1L;
    private static final Long ORGANIZER_ID = 2L;
    private static final Long SECTION_ID = 3L;
    private static final Long VENUE_ID = 4L;
    private static final Long SEAT_ID = 5L;
    private static final String BUYER_ADDRESS = "0xBUYER";
    private static final String ORGANIZER_ADDRESS = "0xORGANIZER";
    private static final Clock CLOCK = Clock.fixed(
            LocalDateTime.of(2026, 9, 21, 12, 0).atZone(ZoneId.of("Asia/Seoul")).toInstant(),
            ZoneId.of("Asia/Seoul"));

    @Mock
    private ReservationRepository reservationRepository;
    @Mock
    private TicketRepository ticketRepository;
    @Mock
    private SectionRepository sectionRepository;
    @Mock
    private WalletService walletService;
    @Mock
    private TicketVaultClient ticketVaultClient;
    @Mock
    private TicketNftClient ticketNftClient;

    private ReservationSettlementRunner runner;

    private Reservation reservation;
    private Ticket ticket;
    private Section section;

    @BeforeEach
    void setUp() {
        runner = new ReservationSettlementRunner(reservationRepository, ticketRepository, sectionRepository,
                walletService, ticketVaultClient, ticketNftClient, CLOCK);

        Member member = mock(Member.class);
        given(member.getId()).willReturn(MEMBER_ID);
        Member organizer = mock(Member.class);
        given(organizer.getId()).willReturn(ORGANIZER_ID);
        Venue venue = mock(Venue.class);
        given(venue.getId()).willReturn(VENUE_ID);
        section = mock(Section.class);
        given(section.getId()).willReturn(SECTION_ID);
        given(section.getPrice()).willReturn(90_000);
        given(section.getVenue()).willReturn(venue);
        Seat seat = mock(Seat.class);
        // charge 단계에서 revert/소진되는 테스트는 여기까지 안 온다.
        lenient().when(seat.getId()).thenReturn(SEAT_ID);
        given(seat.getSection()).willReturn(section);
        Concert concert = mock(Concert.class);
        given(concert.getOrganizer()).willReturn(organizer);
        lenient().when(concert.getShowId()).thenReturn(BigInteger.ONE);
        reservation = mock(Reservation.class);
        given(reservation.getMember()).willReturn(member);
        given(reservation.getConcert()).willReturn(concert);
        given(reservation.getSeat()).willReturn(seat);
        ticket = mock(Ticket.class);

        given(reservationRepository.findById(RESERVATION_ID)).willReturn(Optional.of(reservation));
        given(ticketRepository.findByReservationId(RESERVATION_ID)).willReturn(Optional.of(ticket));
        given(sectionRepository.findAllByVenueIdOrderByIdAsc(VENUE_ID)).willReturn(List.of(section));
        given(walletService.getAddress(MEMBER_ID)).willReturn(BUYER_ADDRESS);
        given(walletService.getAddress(ORGANIZER_ID)).willReturn(ORGANIZER_ADDRESS);
    }

    @Test
    @DisplayName("차감이 일시적으로 실패해도 재시도 끝에 성공하면 정상 진행된다")
    void chargeRetriesOnTransientFailureThenSucceeds() {
        doThrow(new ContractCallException("일시적 오류"))
                .doNothing()
                .when(ticketVaultClient).chargeForBooking(anyString(), anyString(), any(), any());
        given(ticketNftClient.mintTicket(anyString(), any(), any(), anyInt()))
                .willReturn(new MintResult(BigInteger.TEN, "0xMINT"));

        runner.settle(RESERVATION_ID);

        verify(ticketVaultClient, times(2)).chargeForBooking(anyString(), anyString(), any(), any());
        verify(ticket).markMinted(BigInteger.TEN, "0xMINT");
        verify(reservation, never()).cancel(any(), any());
    }

    @Test
    @DisplayName("차감이 revert 되면 재시도 없이 곧바로 주문을 취소한다")
    void chargeStopsImmediatelyOnRevert() {
        willThrow(new ContractRevertException("revert"))
                .given(ticketVaultClient).chargeForBooking(anyString(), anyString(), any(), any());

        runner.settle(RESERVATION_ID);

        verify(ticketVaultClient, times(1)).chargeForBooking(anyString(), anyString(), any(), any());
        verify(ticket).markMintFailed(anyString());
        verify(reservation).cancel(any(), any());
    }

    @Test
    @DisplayName("차감이 일시적 실패를 반복하면 재시도를 소진한 뒤 주문을 취소한다")
    void chargeGivesUpAfterMaxAttemptsOnTransientFailure() {
        willThrow(new ContractCallException("일시적 오류"))
                .given(ticketVaultClient).chargeForBooking(anyString(), anyString(), any(), any());

        runner.settle(RESERVATION_ID);

        verify(ticketVaultClient, times(3)).chargeForBooking(anyString(), anyString(), any(), any());
        verify(ticket).markMintFailed(anyString());
        verify(reservation).cancel(any(), any());
    }

    @Test
    @DisplayName("민팅이 revert 되면 재시도 없이 곧바로 환불을 시도한다")
    void mintStopsImmediatelyOnRevertThenRefunds() {
        willDoNothing().given(ticketVaultClient).chargeForBooking(anyString(), anyString(), any(), any());
        willThrow(new ContractRevertException("revert"))
                .given(ticketNftClient).mintTicket(anyString(), any(), any(), anyInt());

        runner.settle(RESERVATION_ID);

        verify(ticketNftClient, times(1)).mintTicket(anyString(), any(), any(), anyInt());
        verify(ticketVaultClient, times(1)).refund(anyString(), anyString(), any(), any());
        verify(ticket).markRefunded(anyString());
        verify(reservation).cancel(any(), any());
    }

    @Test
    @DisplayName("환불이 일시적 실패를 반복하면 재시도를 소진한 뒤 수동 개입 대상으로 남긴다")
    void refundGivesUpAfterMaxAttemptsMarksFailedForManualIntervention() {
        willDoNothing().given(ticketVaultClient).chargeForBooking(anyString(), anyString(), any(), any());
        willThrow(new ContractCallException("일시적 오류"))
                .given(ticketNftClient).mintTicket(anyString(), any(), any(), anyInt());
        willThrow(new ContractCallException("일시적 오류"))
                .given(ticketVaultClient).refund(anyString(), anyString(), any(), any());

        runner.settle(RESERVATION_ID);

        verify(ticketNftClient, times(3)).mintTicket(anyString(), any(), any(), anyInt());
        verify(ticketVaultClient, times(3)).refund(anyString(), anyString(), any(), any());
        verify(ticket).markMintFailed(anyString());
        verify(reservation, never()).cancel(any(), any());
    }
}
