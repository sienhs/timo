package com.ssafy.timo.domain.offer;

import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.entity.ConcertStatus;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.offer.entity.CancelOffer;
import com.ssafy.timo.domain.offer.entity.OfferStatus;
import com.ssafy.timo.domain.offer.repository.CancelOfferRepository;
import com.ssafy.timo.domain.offer.service.CancelOfferService;
import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.reservation.repository.ReservationRepository;
import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.SeatPosition;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.seat.repository.SeatRepository;
import com.ssafy.timo.domain.seat.repository.SectionRepository;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.domain.wish.entity.ConcertWish;
import com.ssafy.timo.domain.wish.repository.ConcertWishRepository;
import com.ssafy.timo.support.Authenticated;
import com.ssafy.timo.support.IntegrationTest;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigInteger;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.IntStream;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 취소표가 생긴 뒤의 흐름을 API 로 본다 — 좌석표, 선점, 결제까지.
 *
 * <p>예매 취소 자체는 온체인 회수를 부르므로 여기서 못 돌린다. 취소된 주문을 직접 만들고 추첨 서비스를
 * 부른 뒤부터가 이 테스트다. 핵심은 셋이다.
 *
 * <ul>
 *   <li>기회가 열린 자리는 남에게 잡힌 자리로 보이고 남은 잡을 수 없다. 당첨자는 잡을 수 있다</li>
 *   <li>당첨자가 결제하면 기회가 {@code ACCEPTED} 로 닫히고 주문 번호가 남는다</li>
 *   <li>기회가 끝났거나 애초에 없으면 취소된 자리라도 누구나 잡는다 — 영구 잠금이 사라졌다</li>
 * </ul>
 */
@IntegrationTest
class CancelOfferFlowIntegrationTest {

    private static final String SEAT_PATH = "/api/v1/seats";
    private static final String SECTION_PATH = "/api/v1/sections";
    private static final String RESERVATIONS_PATH = "/api/v1/reservations";

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
    private ConcertWishRepository concertWishRepository;
    @Autowired
    private CancelOfferRepository cancelOfferRepository;
    @Autowired
    private CancelOfferService cancelOfferService;
    @Autowired
    private EntityManager em;

    private Concert concert;
    private Section section;
    private Seat revokedSeat;
    private Member canceller;
    private Member winner;
    private Member stranger;
    private Reservation cancelled;

    @BeforeEach
    void setUp() {
        Venue venue = venueRepository.save(Venue.builder()
                .name("고척돔").address("서울시 구로구 경인로 430").totalSeatCount(16000).build());
        section = saveSection(venue);
        revokedSeat = seatRepository.findAllBySectionIdOrderBySeatNoAscSeatColAsc(section.getId()).get(0);

        canceller = saveMember("01011110001", "취소자");
        winner = saveMember("01011110002", "당첨자");
        stranger = saveMember("01011110003", "행인");

        concert = saveOnSaleConcert(venue, canceller);
        // 취소자가 예매했다가 취소한 주문. 온체인 회수는 생략한다.
        cancelled = reservationRepository.save(Reservation.builder()
                .concert(concert).member(canceller).seat(revokedSeat).build());
        cancelled.cancel(LocalDateTime.now());
        // 찜한 사람은 당첨자 한 명뿐이라 추첨 결과가 정해져 있다.
        concertWishRepository.save(ConcertWish.builder().member(winner).concert(concert).build());
        em.flush();
        em.clear();
    }

    @AfterEach
    void clear() {
        Authenticated.clear();
    }

    @Test
    @DisplayName("기회가 열린 자리는 남에게 선점된 자리로 보이고 잔여석에서 빠진다")
    void offeredSeatLooksHeldToOthers() throws Exception {
        cancelOfferService.offerRevokedSeat(concert.getId(), revokedSeat.getId(), cancelled.getId(), canceller.getId());

        mvc.perform(get(SEAT_PATH).param("concertId", id(concert)).param("sectionId", id(section)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.seats[0].status").value("HELD"))
                .andExpect(jsonPath("$.seats[1].status").value("AVAILABLE"))
                .andExpect(jsonPath("$.availableCount").value(3));
        mvc.perform(get(SECTION_PATH).param("concertId", id(concert)))
                .andExpect(jsonPath("$.sections[0].availableCount").value(3));
    }

    @Test
    @DisplayName("남은 그 자리를 잡을 수 없고 당첨자는 잡을 수 있다")
    void onlyWinnerCanHoldOfferedSeat() throws Exception {
        cancelOfferService.offerRevokedSeat(concert.getId(), revokedSeat.getId(), cancelled.getId(), canceller.getId());

        mvc.perform(post(SEAT_PATH + "/{seatId}/hold", revokedSeat.getId()).param("concertId", id(concert))
                        .with(Authenticated.as(stranger.getId())))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.exception").value("SeatNotHoldableException"));

        mvc.perform(post(SEAT_PATH + "/{seatId}/hold", revokedSeat.getId()).param("concertId", id(concert))
                        .with(Authenticated.as(winner.getId())))
                .andExpect(status().isOk());
    }

    @Test
    @DisplayName("당첨자가 선점하고 결제하면 기회가 ACCEPTED 로 닫히고 주문 번호가 남는다")
    void winnerBooksAndOfferIsAccepted() throws Exception {
        CancelOffer offer = cancelOfferService.offerRevokedSeat(
                concert.getId(), revokedSeat.getId(), cancelled.getId(), canceller.getId()).orElseThrow();
        Authenticated.set(winner.getId());

        mvc.perform(post(SEAT_PATH + "/{seatId}/hold", revokedSeat.getId()).param("concertId", id(concert)))
                .andExpect(status().isOk());
        String reservationId = mvc.perform(post(RESERVATIONS_PATH)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"concertId\": %d, \"seatId\": %d}".formatted(concert.getId(), revokedSeat.getId())))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString()
                .replaceAll(".*\"id\":(\\d+).*", "$1");

        em.clear();
        CancelOffer closed = cancelOfferRepository.findById(offer.getId()).orElseThrow();
        assertThat(closed.getStatus()).isEqualTo(OfferStatus.ACCEPTED);
        assertThat(closed.getReservationId()).isEqualTo(Long.valueOf(reservationId));
    }

    @Test
    @DisplayName("기회가 끝난 자리는 취소된 적이 있어도 누구나 잡는다 - 영구 잠금은 없다")
    void expiredOfferFreesTheSeat() throws Exception {
        cancelOfferRepository.saveAndFlush(CancelOffer.builder()
                .concert(concert).seat(revokedSeat).member(winner)
                .sourceReservationId(cancelled.getId())
                .expiresAt(LocalDateTime.now().minusMinutes(1))
                .build());

        mvc.perform(get(SEAT_PATH).param("concertId", id(concert)).param("sectionId", id(section)))
                .andExpect(jsonPath("$.seats[0].status").value("AVAILABLE"))
                .andExpect(jsonPath("$.availableCount").value(4));
        mvc.perform(post(SEAT_PATH + "/{seatId}/hold", revokedSeat.getId()).param("concertId", id(concert))
                        .with(Authenticated.as(stranger.getId())))
                .andExpect(status().isOk());
    }

    @Test
    @DisplayName("찜한 사람이 없으면 기회 없이 곧바로 빈 자리다")
    void noWishersMeansImmediatelyAvailable() throws Exception {
        concertWishRepository.deleteByMemberIdAndConcertId(winner.getId(), concert.getId());

        assertThat(cancelOfferService.offerRevokedSeat(
                concert.getId(), revokedSeat.getId(), cancelled.getId(), canceller.getId())).isEmpty();
        mvc.perform(get(SEAT_PATH).param("concertId", id(concert)).param("sectionId", id(section)))
                .andExpect(jsonPath("$.seats[0].status").value("AVAILABLE"));
    }

    private static String id(Concert concert) {
        return String.valueOf(concert.getId());
    }

    private static String id(Section section) {
        return String.valueOf(section.getId());
    }

    /** 예매 API 가 받아 주는 공연 - 예매 중이고 주최자와 온체인 showId 가 있다. 상태 전이 API 가 없어 직접 넣는다. */
    private Concert saveOnSaleConcert(Venue venue, Member organizer) {
        Concert saved = concertRepository.save(Concert.builder()
                .title("취소표 공연")
                .genre(ConcertGenre.CONCERT)
                .ageRating(AgeRating.ALL)
                .startDate(LocalDateTime.now().plusDays(30))
                .endDate(LocalDateTime.now().plusDays(30).plusHours(3))
                .openAt(LocalDateTime.now().minusDays(1))
                .venue(venue)
                .build());
        saved.prepareForSale(organizer);
        saved.confirmRegistered(BigInteger.ONE);
        ReflectionTestUtils.setField(saved, "status", ConcertStatus.ON_SALE);
        return saved;
    }

    private Member saveMember(String phoneNumber, String nickname) {
        return memberRepository.save(Member.builder()
                .phoneNumber(phoneNumber).name("정희성").nickname(nickname).build());
    }

    private Section saveSection(Venue venue) {
        List<SeatPosition> positions = IntStream.rangeClosed(1, 2)
                .boxed()
                .flatMap(row -> IntStream.rangeClosed(1, 2).mapToObj(col -> new SeatPosition(row, col)))
                .toList();
        Section saved = sectionRepository.save(Section.builder()
                .name("1층 A블록").price(120_000).rowCount(2).seatPerRow(2).venue(venue).build());
        seatRepository.saveAll(saved.createSeats(positions));
        return saved;
    }
}
