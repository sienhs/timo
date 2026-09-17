package com.ssafy.timo.domain.offer;

import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
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
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
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
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigInteger;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.stream.IntStream;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 취소표 구매 기회 통합 테스트. 실제 MySQL 로 추첨 제외 규칙, 조회 응답, 유니크 제약을 본다.
 *
 * <p>난수는 실제 빈이라 "누가" 뽑히는지는 후보가 하나일 때만 단정한다. 여럿일 때는 후보 집합에
 * 들어가는지만 본다. 시드 고정 추첨은 {@code CancelOfferServiceTest} 가 본다.
 */
@IntegrationTest
class CancelOfferApiIntegrationTest {

    private static final String OFFERS_PATH = "/api/v1/offers";
    private static final int SECTION_PRICE = 120_000;

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
    private ConcertWishRepository concertWishRepository;
    @Autowired
    private CancelOfferRepository cancelOfferRepository;
    @Autowired
    private CancelOfferService cancelOfferService;
    @Autowired
    private EntityManager em;

    private Concert concert;
    private Seat revokedSeat;
    private Member canceller;
    private Member holder;
    private Member wisherA;
    private Member wisherB;

    @BeforeEach
    void setUp() {
        Venue venue = venueRepository.save(Venue.builder()
                .name("고척돔").address("서울시 구로구 경인로 430").totalSeatCount(16000).build());
        Section section = saveSection(venue);
        List<Seat> seats = seatRepository.findAllBySectionIdOrderBySeatNoAscSeatColAsc(section.getId());
        revokedSeat = seats.get(0);
        concert = saveConcert(venue, "취소표 공연");

        canceller = saveMember("01011110001", "취소자");
        holder = saveMember("01011110002", "보유자");
        wisherA = saveMember("01011110003", "찜A");
        wisherB = saveMember("01011110004", "찜B");

        // 보유자는 찜도 했지만 이 공연 티켓이 있어 뽑히면 안 된다. 취소자도 찜해 뒀다.
        saveOwnedTicket(concert, seats.get(1), holder);
        for (Member member : List.of(canceller, holder, wisherA, wisherB)) {
            concertWishRepository.save(ConcertWish.builder().member(member).concert(concert).build());
        }
        em.flush();
    }

    @AfterEach
    void clear() {
        Authenticated.clear();
    }

    @Test
    @DisplayName("찜한 회원 중 취소자와 보유자를 뺀 사람이 뽑히고 1시간 기한의 기회가 생긴다")
    void drawsFromEligibleWishers() {
        Optional<CancelOffer> offer = cancelOfferService.offerRevokedSeat(
                concert.getId(), revokedSeat.getId(), 999L, canceller.getId());

        assertThat(offer).isPresent();
        assertThat(offer.get().getMember().getId()).isIn(wisherA.getId(), wisherB.getId());
        assertThat(offer.get().getStatus()).isEqualTo(OfferStatus.OFFERED);
        assertThat(offer.get().getExpiresAt()).isAfter(LocalDateTime.now().plusMinutes(59));
    }

    @Test
    @DisplayName("이미 이 공연에서 기회를 가진 회원은 다시 뽑히지 않는다 - 남은 후보가 하나면 그 사람이다")
    void excludesMembersWithActiveOffer() {
        saveOffer(wisherA, seatOf(2), LocalDateTime.now().plusMinutes(30));

        Optional<CancelOffer> offer = cancelOfferService.offerRevokedSeat(
                concert.getId(), revokedSeat.getId(), 999L, canceller.getId());

        assertThat(offer).isPresent();
        assertThat(offer.get().getMember().getId()).isEqualTo(wisherB.getId());
    }

    @Test
    @DisplayName("찜한 사람이 없으면 기회가 생기지 않는다")
    void noWishersNoOffer() {
        Concert lonely = saveConcert(concert.getVenue(), "아무도 안 찜한 공연");

        Optional<CancelOffer> offer = cancelOfferService.offerRevokedSeat(
                lonely.getId(), revokedSeat.getId(), 999L, canceller.getId());

        assertThat(offer).isEmpty();
    }

    @Test
    @DisplayName("내 기회 목록은 결제에 필요한 값과 서버 시각을 주고, 지난 것과 결제된 것은 빼준다")
    void findMine() throws Exception {
        saveOffer(wisherA, revokedSeat, LocalDateTime.now().plusMinutes(40));
        saveOffer(wisherA, seatOf(2), LocalDateTime.now().minusMinutes(1));     // 지남
        CancelOffer accepted = saveOffer(wisherA, seatOf(3), LocalDateTime.now().plusMinutes(40));
        cancelOfferRepository.markAcceptedIfActive(concert.getId(), seatOf(3).getId(), wisherA.getId(), 55L,
                LocalDateTime.now());
        em.clear();
        Authenticated.set(wisherA.getId());

        mvc.perform(get(OFFERS_PATH + "/me"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.serverTime").exists())
                .andExpect(jsonPath("$.offers.length()").value(1))
                .andExpect(jsonPath("$.offers[0].concertId").value(concert.getId()))
                .andExpect(jsonPath("$.offers[0].concertTitle").value("취소표 공연"))
                .andExpect(jsonPath("$.offers[0].venueName").value("고척돔"))
                .andExpect(jsonPath("$.offers[0].seatId").value(revokedSeat.getId()))
                .andExpect(jsonPath("$.offers[0].sectionName").value("1층 A블록"))
                .andExpect(jsonPath("$.offers[0].seatNo").value(revokedSeat.getSeatNo()))
                .andExpect(jsonPath("$.offers[0].price").value(SECTION_PRICE))
                .andExpect(jsonPath("$.offers[0].expiresAt").exists());

        assertThat(cancelOfferRepository.findById(accepted.getId()).orElseThrow().getStatus())
                .isEqualTo(OfferStatus.ACCEPTED);
    }

    @Test
    @DisplayName("남의 기회는 내 목록에 나오지 않는다")
    void findMineExcludesOthers() throws Exception {
        saveOffer(wisherA, revokedSeat, LocalDateTime.now().plusMinutes(40));
        Authenticated.set(wisherB.getId());

        mvc.perform(get(OFFERS_PATH + "/me"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.offers.length()").value(0));
    }

    @Test
    @DisplayName("한 좌석에 열린 기회는 하나뿐이다 - 지난 기회를 닫아야 다음 기회가 들어간다")
    void oneActiveOfferPerSeat() {
        saveOffer(wisherA, revokedSeat, LocalDateTime.now().minusMinutes(1));

        assertThatThrownBy(() -> saveOffer(wisherB, revokedSeat, LocalDateTime.now().plusMinutes(40)))
                .isInstanceOf(DataIntegrityViolationException.class);

        em.clear();
        assertThat(cancelOfferRepository.expireStaleOfSeat(concert.getId(), revokedSeat.getId(), LocalDateTime.now()))
                .isEqualTo(1);
        saveOffer(wisherB, revokedSeat, LocalDateTime.now().plusMinutes(40));
    }

    @Test
    @DisplayName("결제 마감은 당첨자 본인이 기한 안에 결제했을 때만 성립한다")
    void acceptOnlyForWinnerWithinWindow() {
        saveOffer(wisherA, revokedSeat, LocalDateTime.now().plusMinutes(40));

        assertThat(cancelOfferService.acceptIfActive(concert.getId(), revokedSeat.getId(), wisherB.getId(), 55L)).isFalse();
        assertThat(cancelOfferService.acceptIfActive(concert.getId(), revokedSeat.getId(), wisherA.getId(), 55L)).isTrue();
        // 두 번째는 이미 ACCEPTED 라 0 이다.
        assertThat(cancelOfferService.acceptIfActive(concert.getId(), revokedSeat.getId(), wisherA.getId(), 56L)).isFalse();
    }

    private CancelOffer saveOffer(Member member, Seat seat, LocalDateTime expiresAt) {
        CancelOffer offer = cancelOfferRepository.saveAndFlush(CancelOffer.builder()
                .concert(concert).seat(seat).member(member).sourceReservationId(999L).expiresAt(expiresAt).build());
        em.flush();
        return offer;
    }

    private Seat seatOf(int index) {
        return seatRepository.findAllBySectionIdOrderBySeatNoAscSeatColAsc(revokedSeat.getSection().getId()).get(index);
    }

    private Ticket saveOwnedTicket(Concert forConcert, Seat seat, Member owner) {
        Ticket ticket = ticketRepository.save(Ticket.builder()
                .reservation(reservationRepository.save(Reservation.builder()
                        .concert(forConcert).member(owner).seat(seat).build()))
                .build());
        ticket.markMinted(BigInteger.valueOf(seat.getId()), "0x" + "1".repeat(64));
        return ticket;
    }

    private Concert saveConcert(Venue venue, String title) {
        return concertRepository.save(Concert.builder()
                .title(title)
                .genre(ConcertGenre.CONCERT)
                .ageRating(AgeRating.ALL)
                .startDate(LocalDateTime.now().plusDays(30))
                .endDate(LocalDateTime.now().plusDays(30).plusHours(3))
                .openAt(LocalDateTime.now().plusDays(1))
                .venue(venue)
                .build());
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
                .name("1층 A블록").price(SECTION_PRICE).rowCount(2).seatPerRow(2).venue(venue).build());
        seatRepository.saveAll(saved.createSeats(positions));
        return saved;
    }
}
