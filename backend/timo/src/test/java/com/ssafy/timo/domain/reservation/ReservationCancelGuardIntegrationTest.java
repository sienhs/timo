package com.ssafy.timo.domain.reservation;

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
import com.ssafy.timo.domain.ticket.entity.TicketStatus;
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

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.containsString;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 양도와 얽힌 예매는 취소되지 않아야 한다.
 *
 * <p>체결은 예매 행도 {@code ticket.status} 도 바꾸지 않아, 예매자 검사와 티켓 상태 검사만으로는
 * <b>판 사람이 그대로 통과한다.</b> 그러면 산 사람의 티켓이 회수되고 환불은 판 사람이 받는다.
 * 여기서는 그 두 경로(양도 후, 등록 중)가 온체인 호출 전에 409 로 막히는지 본다.
 *
 * <p><b>성공 경로는 여기서 볼 수 없다.</b> 취소가 성립하면 {@code TicketNftClient.revoke} 가 실제
 * RPC 를 부르는데 테스트에는 체인이 없다. 등록을 취소한 뒤 예매 취소가 다시 열리는지는
 * {@code ReservationCancelGuardTest} 가 목으로 본다.
 */
@IntegrationTest
class ReservationCancelGuardIntegrationTest {

    private static final String RESERVATIONS_PATH = "/api/v1/reservations";
    private static final long FACE_PRICE = 100_000L;

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

    private Member seller;
    private Member buyer;
    private Ticket ticket;

    @BeforeEach
    void setUpFixtures() {
        Venue venue = venueRepository.save(Venue.builder()
                .name("고척돔")
                .address("서울시 구로구 경인로 430")
                .totalSeatCount(16000)
                .build());
        Section section = saveSection(venue);
        Seat seat = seatRepository.findAllBySectionIdOrderBySeatNoAscSeatColAsc(section.getId()).get(0);

        seller = saveMember("01011112222", "판매자");
        buyer = saveMember("01033334444", "구매자");

        // 공연은 30일 뒤라 24시간 컷오프에 걸리지 않는다. 걸리면 여기 검사가 아니라 컷오프 사유로 409 다.
        Concert concert = saveConcert(venue, 30);
        concert.prepareForSale(seller);

        ticket = ticketRepository.save(Ticket.builder()
                .reservation(saveReservation(concert, seat, seller))
                .build());
        ticket.markMinted(BigInteger.valueOf(seat.getId()), "0x" + "1".repeat(64));

        em.flush();
        Authenticated.set(seller.getId());
    }

    @AfterEach
    void clearRequester() {
        Authenticated.clear();
    }

    @Test
    @DisplayName("양도된 티켓의 예매는 판 사람이 취소할 수 없다 - 409 이고 티켓은 그대로 OWNED 다")
    void sellerCannotCancelAfterTransfer() throws Exception {
        TicketListing listing = openListing();
        ticketListingRepository.markSoldIfListed(listing.getId(), LocalDateTime.now());
        ticketTradeRepository.saveAndFlush(TicketTrade.record(listing, buyer.getId(), LocalDateTime.now()));

        mvc.perform(delete(RESERVATIONS_PATH + "/{id}", ticket.getReservation().getId()))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.exception").value("ReservationNotCancellableException"))
                .andExpect(jsonPath("$.errorMessage").value(containsString("양도된 티켓")));

        em.clear();
        assertThat(ticketRepository.findById(ticket.getId()).orElseThrow().getStatus()).isEqualTo(TicketStatus.OWNED);
    }

    @Test
    @DisplayName("되사기로 돌아온 티켓도 취소할 수 없다 - 거래 이력이 있으면 원 주문으로 되돌리지 않는다")
    void sellerCannotCancelAfterBuyback() throws Exception {
        TicketListing first = openListing();
        ticketListingRepository.markSoldIfListed(first.getId(), LocalDateTime.now());
        ticketTradeRepository.saveAndFlush(TicketTrade.record(first, buyer.getId(), LocalDateTime.now()));
        // 구매자가 되팔고 원 예매자가 되산다.
        TicketListing second = ticketListingRepository.saveAndFlush(listingBy(buyer));
        ticketListingRepository.markSoldIfListed(second.getId(), LocalDateTime.now());
        ticketTradeRepository.saveAndFlush(TicketTrade.record(second, seller.getId(), LocalDateTime.now()));

        mvc.perform(delete(RESERVATIONS_PATH + "/{id}", ticket.getReservation().getId()))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.errorMessage").value(containsString("양도된 티켓")));
    }

    @Test
    @DisplayName("양도 등록 중인 티켓의 예매는 취소할 수 없다 - 회수된 티켓이 매물로 남으면 그걸 사는 사람이 생긴다")
    void cannotCancelWhileListed() throws Exception {
        openListing();

        mvc.perform(delete(RESERVATIONS_PATH + "/{id}", ticket.getReservation().getId()))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.exception").value("ReservationNotCancellableException"))
                .andExpect(jsonPath("$.errorMessage").value(containsString("등록 중")));
    }

    private TicketListing openListing() {
        TicketListing listing = ticketListingRepository.saveAndFlush(listingBy(seller));
        em.flush();
        return listing;
    }

    private TicketListing listingBy(Member sellerOfListing) {
        Reservation reservation = ticket.getReservation();
        return TicketListing.open(
                ticket.getId(),
                sellerOfListing.getId(),
                reservation.getConcert(),
                reservation.getSeat().getSection(),
                reservation.getSeat().getSeatNo(),
                reservation.getSeat().getSeatCol(),
                FACE_PRICE,
                FACE_PRICE,
                LocalDateTime.now());
    }

    private Reservation saveReservation(Concert concert, Seat seat, Member member) {
        return reservationRepository.save(Reservation.builder()
                .concert(concert)
                .member(member)
                .seat(seat)
                .build());
    }

    private Concert saveConcert(Venue venue, int daysLater) {
        return concertRepository.save(Concert.builder()
                .title("아이유 콘서트")
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
                .name("정희성")
                .nickname(nickname)
                .build());
    }

    private Section saveSection(Venue venue) {
        List<SeatPosition> positions = IntStream.rangeClosed(1, 2)
                .boxed()
                .flatMap(row -> IntStream.rangeClosed(1, 2).mapToObj(col -> new SeatPosition(row, col)))
                .toList();
        Section saved = sectionRepository.save(Section.builder()
                .name("1층 A블록")
                .price((int) FACE_PRICE)
                .rowCount(2)
                .seatPerRow(2)
                .venue(venue)
                .build());
        seatRepository.saveAll(saved.createSeats(positions));
        return saved;
    }
}
