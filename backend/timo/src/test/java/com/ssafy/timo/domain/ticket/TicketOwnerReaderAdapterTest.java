package com.ssafy.timo.domain.ticket;

import static org.assertj.core.api.Assertions.assertThat;

import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.notification.service.TicketOwnerReader;
import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.reservation.repository.ReservationRepository;
import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.SeatPosition;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.seat.repository.SeatRepository;
import com.ssafy.timo.domain.seat.repository.SectionRepository;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.entity.TicketStatus;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import com.ssafy.timo.domain.transfer.entity.TicketListing;
import com.ssafy.timo.domain.transfer.entity.TicketTrade;
import com.ssafy.timo.domain.transfer.repository.TicketListingRepository;
import com.ssafy.timo.domain.transfer.repository.TicketTradeRepository;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.support.IntegrationTest;
import jakarta.persistence.EntityManager;
import java.math.BigInteger;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.IntStream;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

/**
 * 알림이 티켓 보유자를 묻는 창구를 실제 MySQL 로 확인한다.
 *
 * <p>보유자 판정은 네이티브 쿼리라 기동 시점에 검증되지 않는다. 그리고 이 창구의 계약(취소는 걸러지고
 * 발행 대기는 안 걸러진다)은 호출부가 믿고 쓰는 것이라, 문서에 적힌 대로 실제로 동작하는지 여기서 본다.
 */
@IntegrationTest
class TicketOwnerReaderAdapterTest {

    private static final int SEAT_PRICE = 150_000;
    private static final LocalDateTime NOW = LocalDateTime.of(2026, 9, 20, 9, 0);

    @Autowired
    private TicketOwnerReader reader;

    @Autowired
    private VenueRepository venueRepository;

    @Autowired
    private SectionRepository sectionRepository;

    @Autowired
    private SeatRepository seatRepository;

    @Autowired
    private ConcertRepository concertRepository;

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private ReservationRepository reservationRepository;

    @Autowired
    private TicketRepository ticketRepository;

    @Autowired
    private TicketListingRepository ticketListingRepository;

    @Autowired
    private TicketTradeRepository ticketTradeRepository;

    @Autowired
    private EntityManager em;

    private Venue venue;
    private Section section;
    private List<Seat> seats;
    private Member alice;
    private Member bob;
    private Member carol;

    @BeforeEach
    void setUpFixtures() {
        venue = venueRepository.save(Venue.builder()
                .name("고척돔-" + UUID.randomUUID().toString().substring(0, 6))
                .address("서울시 구로구 경인로 430")
                .totalSeatCount(16000)
                .build());
        section = saveSection(venue);
        seats = seatRepository.findAllBySectionIdOrderBySeatNoAscSeatColAsc(section.getId());
        alice = saveMember("앨리스");
        bob = saveMember("밥");
        carol = saveMember("캐롤");
    }

    @Test
    @DisplayName("예매만 하고 거래가 없으면 예매자가 보유자다")
    void holder_bookedOnly_isBooker() {
        Concert concert = saveConcert("공연");
        book(alice, concert, 0);

        assertThat(holdersOf(concert)).containsExactly(alice.getId());
    }

    @Test
    @DisplayName("양도되면 구매자만 보유자이고 판매자는 빠진다")
    void holder_afterTrade_isBuyerOnly() {
        Concert concert = saveConcert("공연");
        Ticket ticket = book(alice, concert, 0);
        trade(ticket, alice, bob, NOW);

        assertThat(holdersOf(concert)).containsExactly(bob.getId());
    }

    @Test
    @DisplayName("재양도(A→B→C)되면 마지막 구매자 C만 보유자다")
    void holder_afterResale_isLastBuyerOnly() {
        Concert concert = saveConcert("공연");
        Ticket ticket = book(alice, concert, 0);
        trade(ticket, alice, bob, NOW);
        trade(ticket, bob, carol, NOW.plusHours(1));

        assertThat(holdersOf(concert)).containsExactly(carol.getId());
    }

    @Test
    @DisplayName("거래된 적 없는 취소된 예매는 보유자가 아니다")
    void holder_cancelledReservationNeverTraded_isExcluded() {
        Concert concert = saveConcert("공연");
        book(alice, concert, 0);
        Ticket cancelled = book(bob, concert, 1);
        cancelled.getReservation().cancel(NOW, NOW.plusMinutes(10));

        assertThat(holdersOf(concert)).containsExactly(alice.getId());
    }

    @Test
    @DisplayName("발행 대기(PENDING_MINT) 티켓의 예매자도 보유자로 잡힌다 — 호출부가 알아야 하는 계약이다")
    void holder_pendingMint_isNotFilteredOut() {
        Concert concert = saveConcert("공연");
        Ticket pending = ticketRepository.save(Ticket.builder()
                .reservation(reservation(alice, concert, 0)).build());

        assertThat(pending.getStatus()).isEqualTo(TicketStatus.PENDING_MINT);
        assertThat(holdersOf(concert)).containsExactly(alice.getId());
    }

    @Test
    @DisplayName("여러 공연을 한 번에 물으면 공연별로 나뉘고 서로 섞이지 않는다")
    void holder_multipleConcerts_areSeparated() {
        Concert first = saveConcert("첫 공연");
        Concert second = saveConcert("둘째 공연");
        book(alice, first, 0);
        book(bob, second, 1);
        book(carol, second, 2);

        Map<Long, List<Long>> result = reader.findHolderMemberIds(List.of(first.getId(), second.getId()));

        assertThat(result.get(first.getId())).containsExactly(alice.getId());
        assertThat(result.get(second.getId())).containsExactlyInAnyOrder(bob.getId(), carol.getId());
    }

    @Test
    @DisplayName("보유자가 없는 공연도 빈 목록으로 키에 들어 있다")
    void holder_concertWithoutHolders_isPresentWithEmptyList() {
        Concert empty = saveConcert("빈 공연");

        Map<Long, List<Long>> result = reader.findHolderMemberIds(List.of(empty.getId()));

        assertThat(result).containsOnlyKeys(empty.getId());
        assertThat(result.get(empty.getId())).isEmpty();
    }

    @Test
    @DisplayName("같은 공연 id 를 여러 번 줘도 결과는 한 번이다")
    void holder_duplicateConcertIds_areCollapsed() {
        Concert concert = saveConcert("공연");
        book(alice, concert, 0);

        Map<Long, List<Long>> result = reader.findHolderMemberIds(
                List.of(concert.getId(), concert.getId(), concert.getId()));

        assertThat(result).containsOnlyKeys(concert.getId());
        assertThat(result.get(concert.getId())).containsExactly(alice.getId());
    }

    @Test
    @DisplayName("공연 목록이 비어 있으면 빈 맵이다")
    void holder_emptyInput_returnsEmptyMap() {
        assertThat(reader.findHolderMemberIds(List.of())).isEmpty();
    }

    private List<Long> holdersOf(Concert concert) {
        em.flush();
        return reader.findHolderMemberIds(List.of(concert.getId())).get(concert.getId());
    }

    /** 예매하고 발행까지 끝난 티켓. */
    private Ticket book(Member member, Concert concert, int seatIndex) {
        Ticket ticket = ticketRepository.save(Ticket.builder()
                .reservation(reservation(member, concert, seatIndex)).build());
        ticket.markMinted(BigInteger.valueOf(ticket.getId() + 1_000L), "0x" + "1".repeat(64));
        return ticket;
    }

    private Reservation reservation(Member member, Concert concert, int seatIndex) {
        return reservationRepository.save(Reservation.builder()
                .concert(concert)
                .member(member)
                .seat(seats.get(seatIndex))
                .build());
    }

    /** 매물을 열고 바로 체결시킨다. 서비스를 거치지 않는 이유는 소유자 판정만 보면 되기 때문이다. */
    private void trade(Ticket ticket, Member seller, Member buyer, LocalDateTime tradedAt) {
        ticketRepository.findById(ticket.getId()).orElseThrow().markListed();
        TicketListing listing = ticketListingRepository.saveAndFlush(TicketListing.open(
                ticket.getId(),
                seller.getId(),
                ticket.getReservation().getConcert(),
                section,
                ticket.getReservation().getSeat().getSeatNo(),
                ticket.getReservation().getSeat().getSeatCol(),
                SEAT_PRICE - 10_000L,
                SEAT_PRICE,
                NOW));
        em.flush();
        ticketListingRepository.markSoldIfListed(listing.getId(), tradedAt);
        TicketListing sold = ticketListingRepository.findById(listing.getId()).orElseThrow();
        TicketTrade trade = TicketTrade.record(sold, buyer.getId(), tradedAt);
        trade.confirm();
        ticketTradeRepository.save(trade);
        org.assertj.core.api.Assertions.assertThat(ticketRepository.transferOwnershipIfListed(
                ticket.getId(), seller.getId(), buyer.getId(), tradedAt)).isEqualTo(1);
    }

    private Concert saveConcert(String title) {
        return concertRepository.save(Concert.builder()
                .title(title)
                .genre(ConcertGenre.CONCERT)
                .ageRating(AgeRating.ALL)
                .startDate(NOW.plusDays(30))
                .endDate(NOW.plusDays(30).plusHours(3))
                .openAt(NOW.plusDays(1))
                .venue(venue)
                .build());
    }

    private Member saveMember(String nickname) {
        String suffix = UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        return memberRepository.save(Member.builder()
                .phoneNumber("010" + suffix.replaceAll("[a-z]", "1"))
                .name("정희성")
                .nickname(nickname + suffix)
                .build());
    }

    private Section saveSection(Venue forVenue) {
        List<SeatPosition> positions = IntStream.rangeClosed(1, 3)
                .boxed()
                .flatMap(row -> IntStream.rangeClosed(1, 2)
                        .mapToObj(col -> new SeatPosition(row, col)))
                .toList();
        Section saved = sectionRepository.save(Section.builder()
                .name("1층 A블록")
                .price(SEAT_PRICE)
                .rowCount(3)
                .seatPerRow(2)
                .venue(forVenue)
                .build());
        seatRepository.saveAll(saved.createSeats(positions));
        return saved;
    }
}
