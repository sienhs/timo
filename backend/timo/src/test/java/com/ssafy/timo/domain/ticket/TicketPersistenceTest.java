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
import java.time.LocalDateTime;
import com.ssafy.timo.domain.ticket.dto.TicketAcquisition;
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
        assertThat(ticket.getOwnerMemberId()).isEqualTo(ticket.getReservation().getMember().getId());
        assertThat(ticket.getAcquiredBy()).isEqualTo(TicketAcquisition.BOOKING);
        assertThat(ticket.getAcquiredAt()).isEqualTo(ticket.getReservation().getCreatedAt());
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

    @Test
    @DisplayName("소유자와 OWNED 상태를 DB에서 함께 갱신하며 재양도·되사기도 지원한다")
    void transferPersistsOwnerAndStatusTogether() {
        Ticket ticket = ticketRepository.save(ticket(reservation()));
        Long originalOwner = ticket.getOwnerMemberId();
        Long buyer = reservation().getMember().getId();
        LocalDateTime now = LocalDateTime.of(2026, 9, 21, 12, 0);
        ticket.markMinted(BigInteger.valueOf(777), "0xmint");
        ticket.markListed();
        ticketRepository.flush();
        assertThat(ticketRepository.transferOwnershipIfListed(ticket.getId(), buyer, originalOwner, now)).isZero();
        assertThat(ticketRepository.transferOwnershipIfListed(ticket.getId(), originalOwner, buyer, now)).isEqualTo(1);
        Ticket transferred = ticketRepository.findById(ticket.getId()).orElseThrow();
        assertThat(transferred.getOwnerMemberId()).isEqualTo(buyer);
        assertThat(transferred.getStatus()).isEqualTo(TicketStatus.OWNED);
        assertThat(transferred.getAcquiredBy()).isEqualTo(TicketAcquisition.TRANSFER);
        assertThat(transferred.getAcquiredAt()).isEqualTo(now);
        assertThat(transferred.getReservation().getMember().getId()).isEqualTo(originalOwner);
        assertThat(ticketRepository.transferOwnershipIfListed(ticket.getId(), originalOwner, buyer, now)).isZero();
        ticketRepository.findById(ticket.getId()).orElseThrow().markListed();
        assertThat(ticketRepository.transferOwnershipIfListed(ticket.getId(), buyer, originalOwner, now.plusMinutes(1))).isEqualTo(1);
        assertThat(ticketRepository.findById(ticket.getId()).orElseThrow().getOwnerMemberId()).isEqualTo(originalOwner);
    }

    @Test
    @DisplayName("등록 상태가 아닌 티켓은 소유자를 이전하지 않는다")
    void cannotTransferUnlistedTicket() {
        Ticket ticket = ticketRepository.save(ticket(reservation()));
        Long buyer = reservation().getMember().getId();
        assertThat(ticketRepository.transferOwnershipIfListed(ticket.getId(), ticket.getOwnerMemberId(), buyer,
                LocalDateTime.now())).isZero();
        assertThat(ticketRepository.findById(ticket.getId()).orElseThrow().getOwnerMemberId()).isEqualTo(ticket.getOwnerMemberId());
    }

    @Autowired
    private org.springframework.transaction.PlatformTransactionManager transactionManager;

    @Test
    @DisplayName("서로 다른 트랜잭션의 동시 이전은 하나만 커밋되고 새 조회에 반영된다")
    void competingTransfersCommitOnlyOnce() throws Exception {
        Ticket ticket = ticketRepository.save(ticket(reservation()));
        ticket.markMinted(BigInteger.valueOf(991), "0xmint");
        ticket.markListed();
        Long ticketId = ticket.getId();
        Reservation order = ticket.getReservation();
        Long reservationId = order.getId();
        Long ownerId = order.getMember().getId();
        Long seatId = order.getSeat().getId();
        Long sectionId = order.getSeat().getSection().getId();
        Long concertId = order.getConcert().getId();
        Long venueId = order.getConcert().getVenue().getId();
        Member firstBuyer = memberRepository.save(Member.builder().name("buyer1")
                .phoneNumber("010" + UUID.randomUUID().toString().substring(0, 8)).nickname("b1" + UUID.randomUUID().toString().substring(0, 8)).build());
        Member secondBuyer = memberRepository.save(Member.builder().name("buyer2")
                .phoneNumber("010" + UUID.randomUUID().toString().substring(0, 8)).nickname("b2" + UUID.randomUUID().toString().substring(0, 8)).build());
        Long firstId = firstBuyer.getId(), secondId = secondBuyer.getId();
        ticketRepository.flush();
        org.springframework.test.context.transaction.TestTransaction.flagForCommit();
        org.springframework.test.context.transaction.TestTransaction.end();
        var tx = new org.springframework.transaction.support.TransactionTemplate(transactionManager);
        var pool = java.util.concurrent.Executors.newFixedThreadPool(2);
        var start = new java.util.concurrent.CountDownLatch(1);
        LocalDateTime acquiredAt = LocalDateTime.of(2026, 9, 21, 12, 0);
        try {
            var first = pool.submit(() -> {
                start.await();
                return tx.execute(status -> ticketRepository.transferOwnershipIfListed(ticketId, ownerId, firstId, acquiredAt));
            });
            var second = pool.submit(() -> {
                start.await();
                return tx.execute(status -> ticketRepository.transferOwnershipIfListed(ticketId, ownerId, secondId, acquiredAt));
            });
            start.countDown();
            int firstResult = first.get(20, java.util.concurrent.TimeUnit.SECONDS);
            int secondResult = second.get(20, java.util.concurrent.TimeUnit.SECONDS);
            assertThat(firstResult + secondResult).isEqualTo(1);
            tx.executeWithoutResult(status -> {
                Ticket persisted = ticketRepository.findById(ticketId).orElseThrow();
                assertThat(persisted.getOwnerMemberId()).isEqualTo(firstResult == 1 ? firstId : secondId);
                assertThat(persisted.getStatus()).isEqualTo(TicketStatus.OWNED);
                assertThat(persisted.getAcquiredAt()).isEqualTo(acquiredAt);
            });
        } finally {
            start.countDown();
            pool.shutdownNow();
            pool.awaitTermination(30, java.util.concurrent.TimeUnit.SECONDS);
            // 이 테스트에서 커밋한 행만 삭제한다. 기본 롤백 테스트와 데이터를 공유하지 않는다.
            tx.executeWithoutResult(status -> {
                ticketRepository.deleteById(ticketId); ticketRepository.flush();
                reservationRepository.deleteById(reservationId); reservationRepository.flush();
                seatRepository.deleteById(seatId); seatRepository.flush();
                sectionRepository.deleteById(sectionId); sectionRepository.flush();
                concertRepository.deleteById(concertId); concertRepository.flush();
                venueRepository.deleteById(venueId); venueRepository.flush();
                memberRepository.deleteAllById(java.util.List.of(ownerId, firstId, secondId));
            });
        }
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
