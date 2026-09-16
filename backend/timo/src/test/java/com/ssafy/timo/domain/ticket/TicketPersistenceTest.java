package com.ssafy.timo.domain.ticket;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.catchThrowableOfType;

import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.reservation.repository.ReservationRepository;
import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.seat.repository.SeatRepository;
import com.ssafy.timo.domain.seat.repository.SectionRepository;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.entity.TicketStatus;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.support.IntegrationTest;
import java.math.BigInteger;
import java.util.UUID;
import org.hibernate.exception.ConstraintViolationException;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

/**
 * 티켓의 저장·상태 전이·제약을 실제 MySQL 로 확인한다.
 *
 * <p>{@link Reservation}(주문, "이 자리가 팔렸는가")은 팀원 도메인이라 여기서 다시 검증하지 않는다
 * ({@code SeatHoldPersistenceTest} 등이 이미 본다). 여기서 보는 것은 그 위에 얹히는 온체인 발행
 * 진행 상태({@link TicketStatus})뿐이다.
 */
@IntegrationTest
class TicketPersistenceTest {

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private VenueRepository venueRepository;

    @Autowired
    private ConcertRepository concertRepository;

    @Autowired
    private SectionRepository sectionRepository;

    @Autowired
    private SeatRepository seatRepository;

    @Autowired
    private ReservationRepository reservationRepository;

    @Autowired
    private TicketRepository ticketRepository;

    @Test
    @DisplayName("갓 만든 티켓은 PENDING_MINT이고 tokenId가 없다")
    void save_startsAsPendingMintWithNoTokenId() {
        Ticket ticket = ticketRepository.save(ticket(reservation()));

        assertThat(ticket.getStatus()).isEqualTo(TicketStatus.PENDING_MINT);
        assertThat(ticket.getTokenId()).isNull();
        assertThat(ticket.getMintAttemptCount()).isZero();
        assertThat(ticket.getCreatedAt()).isNotNull();
    }

    @Test
    @DisplayName("발행이 확정되면 tokenId·해시가 채워지고 OWNED가 된다")
    void markMinted_setsTokenIdAndStatus() {
        Ticket ticket = ticketRepository.save(ticket(reservation()));

        ticket.markMinted(BigInteger.valueOf(7), "0xabc");

        assertThat(ticket.getStatus()).isEqualTo(TicketStatus.OWNED);
        assertThat(ticket.getTokenId()).isEqualTo(BigInteger.valueOf(7));
        assertThat(ticket.getMintTxHash()).isEqualTo("0xabc");
        assertThat(ticket.getMintAttemptCount()).isEqualTo(1);
    }

    @Test
    @DisplayName("발행이 실패하면 MINT_FAILED가 되고 사유가 남는다")
    void markMintFailed_setsStatusAndReason() {
        Ticket ticket = ticketRepository.save(ticket(reservation()));

        ticket.markMintFailed("체인 응답 없음");

        assertThat(ticket.getStatus()).isEqualTo(TicketStatus.MINT_FAILED);
        assertThat(ticket.getFailureReason()).isEqualTo("체인 응답 없음");
        assertThat(ticket.getMintAttemptCount()).isEqualTo(1);
    }

    @Test
    @DisplayName("보상 환불까지 끝나면 REFUNDED가 된다")
    void markRefunded_setsStatus() {
        Ticket ticket = ticketRepository.save(ticket(reservation()));

        ticket.markRefunded("민팅 실패, 환불 완료");

        assertThat(ticket.getStatus()).isEqualTo(TicketStatus.REFUNDED);
        assertThat(ticket.getFailureReason()).isEqualTo("민팅 실패, 환불 완료");
    }

    @Test
    @DisplayName("예매가 취소되면 REVOKED가 된다")
    void revoke_setsStatus() {
        Ticket ticket = ticketRepository.save(ticket(reservation()));
        ticket.markMinted(BigInteger.valueOf(1), "0xabc");

        ticket.revoke();

        assertThat(ticket.getStatus()).isEqualTo(TicketStatus.REVOKED);
    }

    @Test
    @DisplayName("두 티켓이 같은 tokenId를 가질 수 없다")
    void duplicateTokenId_reportsConstraintName() {
        Ticket first = ticketRepository.save(ticket(reservation()));
        first.markMinted(BigInteger.valueOf(1), "0xabc");
        ticketRepository.saveAndFlush(first);

        Ticket second = ticketRepository.save(ticket(reservation()));
        second.markMinted(BigInteger.valueOf(1), "0xdef");

        assertThat(violatedConstraintOf(() -> ticketRepository.saveAndFlush(second)))
                .isEqualTo("uk_ticket_token_id");
    }

    @Test
    @DisplayName("한 주문에 티켓을 두 번 만들 수 없다")
    void duplicateReservation_reportsConstraintName() {
        Reservation reservation = reservation();
        ticketRepository.saveAndFlush(ticket(reservation));

        assertThat(violatedConstraintOf(() -> ticketRepository.saveAndFlush(ticket(reservation))))
                .isEqualTo("uk_ticket_reservation");
    }

    /** 저장을 터뜨리고, 위반된 유니크 제약의 이름을 꺼낸다. */
    private String violatedConstraintOf(Runnable save) {
        Exception exception = catchThrowableOfType(Exception.class, save::run);
        assertThat(exception).as("중복인데 저장이 통과했다").isNotNull();

        for (Throwable cause = exception; cause != null; cause = cause.getCause()) {
            if (cause instanceof ConstraintViolationException violation) {
                String name = violation.getConstraintName();
                return name == null ? null : name.substring(name.lastIndexOf('.') + 1);
            }
        }
        throw new AssertionError("ConstraintViolationException 을 찾지 못했다: " + exception);
    }

    private Ticket ticket(Reservation reservation) {
        return Ticket.builder().reservation(reservation).build();
    }

    private Reservation reservation() {
        String suffix = UUID.randomUUID().toString().substring(0, 8);
        Member member = memberRepository.save(Member.builder()
                .phoneNumber("010" + suffix.replaceAll("[a-z]", "1"))
                .name("정희성")
                .nickname("티모" + suffix)
                .build());

        Venue venue = venueRepository.save(Venue.builder()
                .name("공연장-" + suffix.substring(0, 6))
                .address("서울시 송파구").totalSeatCount(5000).build());
        Concert concert = concertRepository.save(Concert.builder()
                .title("테스트 공연").genre(ConcertGenre.CONCERT).ageRating(AgeRating.ALL).venue(venue).build());
        Section section = sectionRepository.save(Section.builder()
                .name("A블록").price(50000).rowCount(10).seatPerRow(10).venue(venue).build());
        Seat seat = seatRepository.save(Seat.builder().seatNo(1).seatCol(1).section(section).build());

        return reservationRepository.save(Reservation.builder()
                .concert(concert).member(member).seat(seat).build());
    }
}
