package com.ssafy.timo.domain.seat;

import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.reservation.repository.ReservationRepository;
import com.ssafy.timo.domain.seat.entity.SeatHold;
import com.ssafy.timo.domain.seat.entity.SeatHoldStatus;
import com.ssafy.timo.domain.seat.entity.SeatPosition;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.seat.repository.SeatHoldRepository;
import com.ssafy.timo.domain.seat.repository.SeatRepository;
import com.ssafy.timo.domain.seat.repository.SectionRepository;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.support.IntegrationTest;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.IntStream;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 좌석 선점 취소 API 통합 테스트.
 *
 * <p>취소는 멱등하다 — 이미 빈 자리를 취소해도 200 이다. 만료 직후에 취소를 눌러도 화면에 오류가
 * 뜨면 안 되기 때문이다. 남의 선점과 이미 팔린 자리만 거절한다.
 *
 * <p>선점과 마찬가지로 <b>공연별</b>이다. 한 공연의 취소가 다른 공연의 선점을 건드리지 않는지 본다.
 */
@IntegrationTest
class SeatHoldCancelApiIntegrationTest {

    private static final String SEAT_PATH = "/api/v1/seats";
    private static final String MEMBER_HEADER = "X-Member-Id";

    @Autowired
    private MockMvc mvc;

    @Autowired
    private SectionRepository sectionRepository;

    @Autowired
    private SeatRepository seatRepository;

    @Autowired
    private SeatHoldRepository seatHoldRepository;

    @Autowired
    private ReservationRepository reservationRepository;

    @Autowired
    private VenueRepository venueRepository;

    @Autowired
    private ConcertRepository concertRepository;

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private EntityManager em;

    private Venue venue;
    private Section section;
    private Concert concertA;
    private Concert concertB;
    private long me;
    private long someoneElse;

    @BeforeEach
    void setUpFixtures() {
        venue = venueRepository.save(Venue.builder()
                .name("고척돔")
                .address("서울시 구로구 경인로 430")
                .totalSeatCount(16000)
                .build());

        concertA = saveConcert("9월 20일 공연", LocalDateTime.now().plusDays(20));
        concertB = saveConcert("9월 21일 공연", LocalDateTime.now().plusDays(21));

        me = saveMember("01011112222", "나").getId();
        someoneElse = saveMember("01033334444", "남").getId();

        section = saveSection("1층 A블록", 150000, 2, 2);
        flushAndClear();
    }

    @Test
    @DisplayName("내 선점을 취소하면 200 과 함께 예매 가능으로 알려준다")
    void cancel_releasesMyHold() throws Exception {
        Long seatId = seatIdAt(1, 1);
        mvc.perform(holdBy(me, concertA, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(cancelBy(me, concertA, seatId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.seatId").value(seatId.intValue()))
                .andExpect(jsonPath("$.sectionName").value("1층 A블록"))
                .andExpect(jsonPath("$.status").value("AVAILABLE"));
        flushAndClear();

        assertThat(seatHoldRepository.findActive(concertA.getId(), seatId, LocalDateTime.now()))
                .isEmpty();
    }

    @Test
    @DisplayName("취소한 선점은 지워지지 않고 RELEASED 로 사유가 남는다")
    void cancel_keepsRowWithReleasedStatus() throws Exception {
        Long seatId = seatIdAt(1, 1);
        mvc.perform(holdBy(me, concertA, seatId)).andExpect(status().isOk());
        flushAndClear();

        Long holdId = seatHoldRepository.findActive(concertA.getId(), seatId, LocalDateTime.now())
                .orElseThrow().getId();

        mvc.perform(cancelBy(me, concertA, seatId)).andExpect(status().isOk());
        flushAndClear();

        SeatHold hold = seatHoldRepository.findById(holdId).orElseThrow();
        assertThat(hold.getStatus()).isEqualTo(SeatHoldStatus.RELEASED);
        assertThat(hold.getReleasedAt()).isNotNull();
    }

    @Test
    @DisplayName("취소하면 좌석 목록에서 다시 예매 가능으로 보인다")
    void cancel_reflectedInSeatList() throws Exception {
        Long seatId = seatIdAt(1, 1);
        mvc.perform(holdBy(me, concertA, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(cancelBy(me, concertA, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(seatsOf(concertA))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.seats[0].status").value("AVAILABLE"))
                .andExpect(jsonPath("$.availableCount").value(4));
    }

    @Test
    @DisplayName("취소한 자리는 다시 선점할 수 있다")
    void cancelledSeat_canBeHeldAgain() throws Exception {
        Long seatId = seatIdAt(1, 1);
        mvc.perform(holdBy(me, concertA, seatId)).andExpect(status().isOk());
        flushAndClear();
        mvc.perform(cancelBy(me, concertA, seatId)).andExpect(status().isOk());
        flushAndClear();

        // 끝난 선점 행이 남아 있어도 유니크 제약에 걸리지 않아야 한다.
        mvc.perform(holdBy(someoneElse, concertA, seatId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("HELD"));
    }

    @Test
    @DisplayName("아무도 잡지 않은 자리를 취소해도 200 이다")
    void cancel_isIdempotentOnFreeSeat() throws Exception {
        mvc.perform(cancelBy(me, concertA, seatIdAt(1, 1)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("AVAILABLE"));
    }

    @Test
    @DisplayName("만료된 내 선점을 취소해도 200 이다")
    void cancel_isIdempotentOnExpiredHold() throws Exception {
        Long seatId = seatIdAt(1, 1);
        mvc.perform(holdBy(me, concertA, seatId)).andExpect(status().isOk());
        expireHold(concertA, seatId);

        mvc.perform(cancelBy(me, concertA, seatId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("AVAILABLE"));
    }

    @Test
    @DisplayName("남이 잡고 있는 좌석은 403 이다")
    void cancel_returnsForbiddenWhenHeldByOther() throws Exception {
        Long seatId = seatIdAt(1, 1);
        mvc.perform(holdBy(someoneElse, concertA, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(cancelBy(me, concertA, seatId))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.exception").value("SeatHoldNotOwnedException"));
        flushAndClear();

        assertThat(seatHoldRepository.findActive(concertA.getId(), seatId, LocalDateTime.now()))
                .as("남의 선점이 풀렸다").isPresent();
    }

    @Test
    @DisplayName("이미 팔린 좌석은 403 이다")
    void cancel_returnsForbiddenWhenSold() throws Exception {
        Long seatId = seatIdAt(1, 1);
        sell(concertA, seatId, someoneElse);
        flushAndClear();

        mvc.perform(cancelBy(me, concertA, seatId))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.exception").value("SeatHoldNotOwnedException"));
    }

    @Test
    @DisplayName("한 공연의 취소는 다른 공연의 선점을 건드리지 않는다")
    void cancel_doesNotTouchOtherConcertHold() throws Exception {
        Long seatId = seatIdAt(1, 1);
        mvc.perform(holdBy(me, concertA, seatId)).andExpect(status().isOk());
        mvc.perform(holdBy(me, concertB, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(cancelBy(me, concertA, seatId)).andExpect(status().isOk());
        flushAndClear();

        assertThat(seatHoldRepository.findActive(concertA.getId(), seatId, LocalDateTime.now()))
                .isEmpty();
        assertThat(seatHoldRepository.findActive(concertB.getId(), seatId, LocalDateTime.now()))
                .as("다른 공연의 선점까지 풀렸다").isPresent();
    }

    @Test
    @DisplayName("존재하지 않는 좌석이면 404 다")
    void cancel_returnsNotFoundWhenSeatMissing() throws Exception {
        mvc.perform(delete(SEAT_PATH + "/{seatId}/hold", 999_999L)
                        .param("concertId", String.valueOf(concertA.getId()))
                        .header(MEMBER_HEADER, me))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.exception").value("SeatNotFoundException"));
    }

    @Test
    @DisplayName("요청자를 특정할 수 없으면 401 이다")
    void cancel_returnsUnauthorizedWhenMemberHeaderMissing() throws Exception {
        mvc.perform(delete(SEAT_PATH + "/{seatId}/hold", seatIdAt(1, 1))
                        .param("concertId", String.valueOf(concertA.getId())))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.exception").value("TokenInvalidException"));
    }

    // ---------------------------------------------------------------- 헬퍼

    private MockHttpServletRequestBuilder holdBy(long memberId, Concert concert, Long seatId) {
        return post(SEAT_PATH + "/{seatId}/hold", seatId)
                .param("concertId", String.valueOf(concert.getId()))
                .header(MEMBER_HEADER, memberId);
    }

    private MockHttpServletRequestBuilder cancelBy(long memberId, Concert concert, Long seatId) {
        return delete(SEAT_PATH + "/{seatId}/hold", seatId)
                .param("concertId", String.valueOf(concert.getId()))
                .header(MEMBER_HEADER, memberId);
    }

    private MockHttpServletRequestBuilder seatsOf(Concert concert) {
        return get(SEAT_PATH)
                .param("concertId", String.valueOf(concert.getId()))
                .param("sectionId", String.valueOf(section.getId()));
    }

    private void sell(Concert concert, Long seatId, long memberId) {
        reservationRepository.save(Reservation.builder()
                .concert(concert)
                .member(memberRepository.getReferenceById(memberId))
                .seat(seatRepository.getReferenceById(seatId))
                .build());
    }

    private Long seatIdAt(int seatNo, int seatCol) {
        return seatRepository.findAllBySectionIdOrderBySeatNoAscSeatColAsc(section.getId()).stream()
                .filter(seat -> seat.getSeatNo() == seatNo && seat.getSeatCol() == seatCol)
                .findFirst()
                .orElseThrow()
                .getId();
    }

    private void expireHold(Concert concert, Long seatId) {
        SeatHold hold = seatHoldRepository.findActive(concert.getId(), seatId, LocalDateTime.now())
                .orElseThrow();
        ReflectionTestUtils.setField(hold, "expiresAt", LocalDateTime.now().minusMinutes(1));
        seatHoldRepository.save(hold);
        flushAndClear();
    }

    private Concert saveConcert(String title, LocalDateTime startDate) {
        return concertRepository.save(Concert.builder()
                .title(title)
                .genre(ConcertGenre.CONCERT)
                .ageRating(AgeRating.ALL)
                .startDate(startDate)
                .endDate(startDate.plusHours(3))
                .openAt(startDate.minusDays(10))
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

    private Section saveSection(String name, int price, int rowCount, int seatPerRow) {
        List<SeatPosition> positions = IntStream.rangeClosed(1, rowCount)
                .boxed()
                .flatMap(row -> IntStream.rangeClosed(1, seatPerRow)
                        .mapToObj(col -> new SeatPosition(row, col)))
                .toList();

        Section saved = sectionRepository.save(Section.builder()
                .name(name)
                .price(price)
                .rowCount(rowCount)
                .seatPerRow(seatPerRow)
                .venue(venue)
                .build());

        seatRepository.saveAll(saved.createSeats(positions));
        return saved;
    }

    private void flushAndClear() {
        em.flush();
        em.clear();
    }
}
