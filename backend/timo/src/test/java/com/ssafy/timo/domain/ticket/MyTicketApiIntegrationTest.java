package com.ssafy.timo.domain.ticket;

import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.reservation.repository.ReservationRepository;
import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.SeatPosition;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.seat.repository.SeatRepository;
import com.ssafy.timo.domain.seat.repository.SectionRepository;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import com.ssafy.timo.domain.transfer.entity.TicketListing;
import com.ssafy.timo.domain.transfer.entity.TicketTrade;
import com.ssafy.timo.domain.transfer.repository.TicketListingRepository;
import com.ssafy.timo.domain.transfer.repository.TicketTradeRepository;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.support.Authenticated;
import com.ssafy.timo.support.IntegrationTest;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigInteger;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.IntStream;

import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.containsInAnyOrder;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 내 티켓 조회 API 통합 테스트.
 *
 * <p><b>소유자 판정이 전부 네이티브 쿼리 안에 있어 여기서만 검증된다.</b> JPQL 과 달리 기동 시점에
 * 검증되지 않아 컬럼명이나 별칭이 틀려도 호출해 봐야 안다.
 *
 * <p>덮는 것은 판정의 두 갈래와 함정 둘이다 — 재양도({@code A->B->C})는 {@code MAX(trade_id)} 를
 * 쓰는 이유이고, 되사기({@code A->B->A})는 두 갈래로 모든 경우가 덮이는지를 본다.
 */
@IntegrationTest
class MyTicketApiIntegrationTest {

    private static final String MY_TICKETS_PATH = "/api/v1/tickets/me";
    private static final int SEAT_PRICE = 150_000;

    @Autowired
    private MockMvc mvc;

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

    private Section section;
    private List<Seat> seats;
    private Member alice;
    private Member bob;
    private Member carol;
    private Venue venue;

    @BeforeEach
    void setUpFixtures() {
        Venue venue = venueRepository.save(Venue.builder()
                .name("고척돔")
                .address("서울시 구로구 경인로 430")
                .totalSeatCount(16000)
                .build());

        section = saveSection(venue);
        seats = seatRepository.findAllBySectionIdOrderBySeatNoAscSeatColAsc(section.getId());

        alice = saveMember("01011112222", "앨리스");
        bob = saveMember("01033334444", "밥");
        carol = saveMember("01055556666", "캐롤");

        this.venue = venue;
    }

    @AfterEach
    void clearRequester() {
        Authenticated.clear();
    }

    @Test
    @DisplayName("예매만 하고 거래가 없으면 예매자의 목록에 나온다")
    void bookedOnly() throws Exception {
        Ticket ticket = book(alice, 0, "아이유 콘서트");
        em.flush();

        Authenticated.set(alice.getId());
        mvc.perform(get(MY_TICKETS_PATH))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(1))
                .andExpect(jsonPath("$.content[0].ticketId").value(ticket.getId().intValue()))
                .andExpect(jsonPath("$.content[0].acquiredBy").value("BOOKING"))
                .andExpect(jsonPath("$.content[0].ticketStatus").value("OWNED"))
                .andExpect(jsonPath("$.content[0].facePrice").value(SEAT_PRICE))
                .andExpect(jsonPath("$.content[0].concertTitle").value("아이유 콘서트"))
                .andExpect(jsonPath("$.content[0].sectionName").value("1층 A블록"))
                // 아직 매물이 아니라 등록 버튼을 가릴 이유가 없다.
                .andExpect(jsonPath("$.content[0].listed").value(false));
    }

    @Test
    @DisplayName("판 티켓은 판 사람 목록에서 빠지고 산 사람 목록에 들어온다 - 이 API 의 존재 이유")
    void soldTicketMovesToBuyer() throws Exception {
        Ticket ticket = book(alice, 0, "아이유 콘서트");
        trade(ticket, alice, bob, LocalDateTime.now().minusDays(2));
        em.flush();

        Authenticated.set(alice.getId());
        mvc.perform(get(MY_TICKETS_PATH))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(0));

        Authenticated.set(bob.getId());
        mvc.perform(get(MY_TICKETS_PATH))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(1))
                .andExpect(jsonPath("$.content[0].ticketId").value(ticket.getId().intValue()))
                .andExpect(jsonPath("$.content[0].acquiredBy").value("TRANSFER"));
    }

    @Test
    @DisplayName("재양도하면 마지막 산 사람만 가진다 - MAX(trade_id) 를 쓰는 이유")
    void resoldTwice() throws Exception {
        Ticket ticket = book(alice, 0, "아이유 콘서트");
        trade(ticket, alice, bob, LocalDateTime.now().minusDays(3));
        trade(ticket, bob, carol, LocalDateTime.now().minusDays(1));
        em.flush();

        assertHolds(alice);
        assertHolds(bob);
        assertHolds(carol, ticket);
    }

    @Test
    @DisplayName("팔았다가 되사면 다시 내 것이다 - 두 갈래가 모든 경우를 덮는지 본다")
    void boughtBack() throws Exception {
        Ticket ticket = book(alice, 0, "아이유 콘서트");
        trade(ticket, alice, bob, LocalDateTime.now().minusDays(3));
        trade(ticket, bob, alice, LocalDateTime.now().minusDays(1));
        em.flush();

        // 거래가 있으므로 "예매했고 거래 없음" 갈래에서는 빠진다. 반대 갈래가 잡아야 한다.
        assertHolds(alice, ticket);
        assertHolds(bob);
    }

    @Test
    @DisplayName("남의 티켓은 나오지 않는다")
    void othersTicketHidden() throws Exception {
        book(bob, 0, "아이유 콘서트");
        em.flush();

        assertHolds(alice);
    }

    @Test
    @DisplayName("여러 장이면 최근에 내 것이 된 순으로 나온다")
    void orderedByAcquiredAt() throws Exception {
        Ticket old = book(alice, 0, "오래된 공연");
        Ticket bought = book(bob, 1, "새로 산 공연");
        trade(bought, bob, alice, LocalDateTime.now().plusDays(1));
        em.flush();

        Authenticated.set(alice.getId());
        mvc.perform(get(MY_TICKETS_PATH))
                .andExpect(jsonPath("$.content.length()").value(2))
                // 방금 산 것이 먼저다.
                .andExpect(jsonPath("$.content[*].ticketId",
                        contains(bought.getId().intValue(), old.getId().intValue())))
                .andExpect(jsonPath("$.content[*].acquiredBy", contains("TRANSFER", "BOOKING")));
    }

    @Test
    @DisplayName("양도 등록 중이면 listed 가 true 다 - 등록 버튼을 미리 가릴 수 있다")
    void listedFlag() throws Exception {
        Ticket listedTicket = book(alice, 0, "등록한 공연");
        Ticket plainTicket = book(alice, 1, "그냥 가진 공연");
        openListing(listedTicket, alice);
        em.flush();

        Authenticated.set(alice.getId());
        mvc.perform(get(MY_TICKETS_PATH))
                .andExpect(jsonPath("$.content.length()").value(2))
                .andExpect(jsonPath("$.content[?(@.ticketId == %d)].listed".formatted(listedTicket.getId()))
                        .value(true))
                .andExpect(jsonPath("$.content[?(@.ticketId == %d)].listed".formatted(plainTicket.getId()))
                        .value(false));
    }

    @Test
    @DisplayName("가진 티켓이 없으면 빈 목록이다")
    void empty() throws Exception {
        Authenticated.set(alice.getId());
        mvc.perform(get(MY_TICKETS_PATH))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(0))
                .andExpect(jsonPath("$.page.totalElements").value(0));
    }

    @Test
    @DisplayName("페이지 크기가 상한을 넘으면 400")
    void pageSizeTooLarge() throws Exception {
        Authenticated.set(alice.getId());
        mvc.perform(get(MY_TICKETS_PATH).param("size", "101"))
                .andExpect(status().isBadRequest());
    }

    // ---------------------------------------------------------------- 헬퍼

    /** 이 회원의 보유 목록이 정확히 이 티켓들인지 본다. */
    private void assertHolds(Member member, Ticket... expected) throws Exception {
        Integer[] ids = java.util.Arrays.stream(expected)
                .map(ticket -> ticket.getId().intValue())
                .toArray(Integer[]::new);

        Authenticated.set(member.getId());
        mvc.perform(get(MY_TICKETS_PATH))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(ids.length))
                .andExpect(jsonPath("$.content[*].ticketId", containsInAnyOrder(ids)));
    }

    /** 예매하고 발행까지 끝난 티켓을 만든다. 공연을 새로 만드는 이유는 한 계정 한 공연 1매 때문이다. */
    private Ticket book(Member member, int seatIndex, String concertTitle) {
        Concert concert = saveConcert(concertTitle, 20 + seatIndex);
        Reservation reservation = reservationRepository.save(Reservation.builder()
                .concert(concert)
                .member(member)
                .seat(seats.get(seatIndex))
                .build());

        Ticket ticket = ticketRepository.save(Ticket.builder().reservation(reservation).build());
        ticket.markMinted(BigInteger.valueOf(ticket.getId() + 1_000L), "0x" + "1".repeat(64));
        return ticket;
    }

    /** 매물을 열고 바로 체결시킨다. 서비스를 거치지 않는 이유는 소유자 판정만 보면 되기 때문이다. */
    private void trade(Ticket ticket, Member seller, Member buyer, LocalDateTime tradedAt) {
        TicketListing listing = openListing(ticket, seller);
        ticketListingRepository.markSoldIfListed(listing.getId(), tradedAt);
        TicketListing sold = ticketListingRepository.findById(listing.getId()).orElseThrow();

        ticketTradeRepository.save(TicketTrade.record(sold, buyer.getId(), tradedAt));
    }

    private TicketListing openListing(Ticket ticket, Member seller) {
        TicketListing listing = ticketListingRepository.saveAndFlush(TicketListing.open(
                ticket.getId(),
                seller.getId(),
                ticket.getReservation().getConcert(),
                section,
                ticket.getReservation().getSeat().getSeatNo(),
                ticket.getReservation().getSeat().getSeatCol(),
                SEAT_PRICE - 10_000L,
                SEAT_PRICE,
                LocalDateTime.now()));
        em.flush();
        return listing;
    }

    private Concert saveConcert(String title, int daysLater) {
        return concertRepository.save(Concert.builder()
                .title(title)
                .genre(ConcertGenre.CONCERT)
                .ageRating(AgeRating.ALL)
                .startDate(LocalDateTime.now().plusDays(daysLater))
                .endDate(LocalDateTime.now().plusDays(daysLater).plusHours(3))
                .openAt(LocalDateTime.now().plusDays(1))
                .venue(venue)
                .build());
    }

    private Member saveMember(String phoneNumber, String nickname) {
        return memberRepository.save(Member.builder()
                .phoneNumber(phoneNumber)
                .name("전재민")
                .nickname(nickname)
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
