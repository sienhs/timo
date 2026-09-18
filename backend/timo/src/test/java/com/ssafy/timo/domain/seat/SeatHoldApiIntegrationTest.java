package com.ssafy.timo.domain.seat;

import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.entity.ConcertStatus;
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
import com.ssafy.timo.global.security.exception.AuthErrorCode;
import com.ssafy.timo.support.Authenticated;
import com.ssafy.timo.support.IntegrationTest;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.AfterEach;
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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 좌석 선점 API 통합 테스트.
 *
 * <p>선점은 이제 <b>공연별</b>이다. 같은 공연장에서 열리는 두 공연이 같은 좌석을 각자 팔 수 있어야
 * 하므로, 이 테스트는 공연장 하나에 공연 둘을 두고 <b>서로 간섭하지 않는지</b>를 핵심으로 본다.
 *
 * <p>요청자는 access token 의 {@code sub} 로 정해진다({@code @AuthenticationPrincipal}).
 * {@code addFilters = false} 라 필터가 인증 객체를 만들어 주지 않으므로
 * {@link Authenticated} 가 홀더에 직접 넣는다. 다만 선점 행이 회원 FK 를 들고 있어 아무 숫자나
 * 쓸 수는 없고, 실제로 저장한 회원 id 를 쓴다.
 *
 * <p><b>동시 선점은 여기서 검증하지 않는다.</b> {@code @IntegrationTest} 가 테스트 전체를 한
 * 트랜잭션으로 묶으므로 두 요청을 실제로 겹치게 만들 수 없다. 판정을 맡은 유니크 제약이 스키마에
 * 실제로 만들어지는지는 {@code SeatHoldPersistenceTest} 가 본다.
 *
 * <p>만료는 시계를 돌리지 않고 {@code expires_at} 을 과거로 직접 써서 만든다. 컨텍스트를 공유하는
 * 규약 때문에 {@code Clock} 빈을 갈아 끼울 수 없다.
 */
@IntegrationTest
class SeatHoldApiIntegrationTest {

    private static final String SEAT_PATH = "/api/v1/seats";
    private static final String SECTION_PATH = "/api/v1/sections";

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

        // 같은 공연장, 다른 날짜. 좌석 행을 공유하지만 판매는 서로 독립이어야 한다.
        concertA = saveConcert("9월 20일 공연", LocalDateTime.now().plusDays(20));
        concertB = saveConcert("9월 21일 공연", LocalDateTime.now().plusDays(21));

        me = saveMember("01011112222", "나").getId();
        someoneElse = saveMember("01033334444", "남").getId();

        section = saveSection("1층 A블록", 150000, 2, 2);
        flushAndClear();
    }

    @AfterEach
    void clearAuthentication() {
        // 홀더는 스레드에 남는다. 비우지 않으면 다음 테스트가 이 요청자를 물려받는다.
        Authenticated.clear();
    }

    // ---------------------------------------------------------------- 선점 성공

    @Test
    @DisplayName("좌석을 선점하면 200 과 함께 만료 시각을 5분 뒤로 알려준다")
    void hold_returnsOkWithExpiryFiveMinutesLater() throws Exception {
        Long seatId = seatIdAt(1, 1);
        LocalDateTime before = LocalDateTime.now();

        String expiresAt = mvc.perform(holdBy(me, concertA, seatId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.seatId").value(seatId.intValue()))
                .andExpect(jsonPath("$.sectionId").value(section.getId().intValue()))
                .andExpect(jsonPath("$.sectionName").value("1층 A블록"))
                .andExpect(jsonPath("$.seatNo").value(1))
                .andExpect(jsonPath("$.seatCol").value(1))
                .andExpect(jsonPath("$.status").value("HELD"))
                .andExpect(jsonPath("$.releasedSeatId").isEmpty())
                .andReturn().getResponse().getContentAsString()
                .replaceAll(".*\"expiresAt\":\"([^\"]+)\".*", "$1");

        // 시계를 고정할 수 없으므로 5분 전후 여유를 두고 본다.
        assertThat(LocalDateTime.parse(expiresAt))
                .isAfter(before.plusMinutes(4).plusSeconds(50))
                .isBefore(before.plusMinutes(5).plusSeconds(10));
    }

    @Test
    @DisplayName("선점하면 그 공연의 선점 행이 HELD 로 남고 누가 언제까지 잡았는지 기록된다")
    void hold_persistsHoldRow() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(me, concertA, seatId)).andExpect(status().isOk());
        flushAndClear();

        SeatHold hold = activeHold(concertA, seatId);
        assertThat(hold.getStatus()).isEqualTo(SeatHoldStatus.HELD);
        assertThat(hold.getMember().getId()).isEqualTo(me);
        assertThat(hold.getConcert().getId()).isEqualTo(concertA.getId());
        assertThat(hold.getExpiresAt()).isAfter(LocalDateTime.now());
        assertThat(hold.getReleasedAt()).isNull();
    }

    @Test
    @DisplayName("선점한 좌석은 그 공연의 좌석 목록에서 HELD 로 보이고 잔여석에서 빠진다")
    void hold_reflectedInSeatListAndAvailableCount() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(me, concertA, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(seatsOf(concertA))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.seatCount").value(4))
                .andExpect(jsonPath("$.availableCount").value(3))
                .andExpect(jsonPath("$.seats[0].status").value("HELD"));

        mvc.perform(sectionsOf(concertA))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.sections[0].availableCount").value(3));
    }

    // ------------------------------------------------- 공연 격리 (스토리 2 · 3 의 핵심)

    @Test
    @DisplayName("공연 A 에서 선점한 좌석이 공연 B 의 좌석표에서는 예매 가능이다")
    void hold_inOneConcert_doesNotAffectAnotherConcertSeatMap() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(me, concertA, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(seatsOf(concertA))
                .andExpect(jsonPath("$.seats[0].status").value("HELD"))
                .andExpect(jsonPath("$.availableCount").value(3));

        mvc.perform(seatsOf(concertB))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.seats[0].status").value("AVAILABLE"))
                .andExpect(jsonPath("$.availableCount").value(4));
    }

    @Test
    @DisplayName("공연 A 에서 판매된 좌석이 공연 B 의 좌석표에서는 예매 가능이다")
    void soldSeat_inOneConcert_isAvailableInAnother() throws Exception {
        Long seatId = seatIdAt(1, 1);
        sell(concertA, seatId, me);
        flushAndClear();

        mvc.perform(seatsOf(concertA))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.seats[0].status").value("SOLD"))
                .andExpect(jsonPath("$.availableCount").value(3));

        mvc.perform(seatsOf(concertB))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.seats[0].status").value("AVAILABLE"))
                .andExpect(jsonPath("$.availableCount").value(4));
    }

    @Test
    @DisplayName("같은 좌석이라도 공연이 다르면 서로 선점을 막지 않는다")
    void sameSeat_canBeHeldByDifferentMembersInDifferentConcerts() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(someoneElse, concertA, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(holdBy(me, concertB, seatId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.seatId").value(seatId.intValue()));
        flushAndClear();

        assertThat(activeHold(concertA, seatId).getMember().getId()).isEqualTo(someoneElse);
        assertThat(activeHold(concertB, seatId).getMember().getId()).isEqualTo(me);
    }

    @Test
    @DisplayName("다른 공연에서 잡고 있던 내 선점은 이번 선점 때문에 풀리지 않는다")
    void hold_doesNotReleaseMyHoldInAnotherConcert() throws Exception {
        Long first = seatIdAt(1, 1);
        Long second = seatIdAt(1, 2);

        mvc.perform(holdBy(me, concertA, first)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(holdBy(me, concertB, second))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.releasedSeatId").isEmpty());
        flushAndClear();

        assertThat(seatHoldRepository.findActive(concertA.getId(), first, LocalDateTime.now()))
                .as("다른 공연의 선점까지 풀렸다").isPresent();
    }

    // ---------------------------------------------------------------- 한 공연 한 자리

    @Test
    @DisplayName("같은 공연에서 새 좌석을 선점하면 이전 선점이 풀리고 어디가 풀렸는지 알려준다")
    void hold_releasesPreviousHoldInSameConcert() throws Exception {
        Long first = seatIdAt(1, 1);
        Long second = seatIdAt(1, 2);

        mvc.perform(holdBy(me, concertA, first)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(holdBy(me, concertA, second))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.seatId").value(second.intValue()))
                .andExpect(jsonPath("$.releasedSeatId").value(first.intValue()));
        flushAndClear();

        assertThat(seatHoldRepository.findActive(concertA.getId(), first, LocalDateTime.now()))
                .isEmpty();
        assertThat(activeHold(concertA, second).getMember().getId()).isEqualTo(me);
    }

    @Test
    @DisplayName("남의 선점은 내가 새로 선점해도 풀리지 않는다")
    void hold_doesNotReleaseOtherMembersHold() throws Exception {
        Long theirs = seatIdAt(1, 1);
        Long mine = seatIdAt(1, 2);

        mvc.perform(holdBy(someoneElse, concertA, theirs)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(holdBy(me, concertA, mine))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.releasedSeatId").isEmpty());
        flushAndClear();

        assertThat(activeHold(concertA, theirs).getMember().getId()).isEqualTo(someoneElse);
    }

    @Test
    @DisplayName("이미 내가 잡은 좌석을 다시 선점하면 만료 시각만 미뤄진다")
    void hold_extendsExpiryWhenAlreadyMine() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(me, concertA, seatId)).andExpect(status().isOk());
        flushAndClear();

        // 만료가 임박한 상태로 만들어, 갱신이 실제로 일어나는지 본다.
        LocalDateTime almostExpired = LocalDateTime.now().plusSeconds(10);
        setExpiresAt(activeHold(concertA, seatId).getId(), almostExpired);
        flushAndClear();

        mvc.perform(holdBy(me, concertA, seatId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.releasedSeatId").isEmpty());
        flushAndClear();

        assertThat(activeHold(concertA, seatId).getExpiresAt()).isAfter(almostExpired);
    }

    // ---------------------------------------------------------------- 만료

    @Test
    @DisplayName("만료된 선점은 다른 회원이 인수할 수 있다")
    void hold_takesOverExpiredHold() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(someoneElse, concertA, seatId)).andExpect(status().isOk());
        expireHold(concertA, seatId);

        mvc.perform(holdBy(me, concertA, seatId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.seatId").value(seatId.intValue()));
        flushAndClear();

        assertThat(activeHold(concertA, seatId).getMember().getId()).isEqualTo(me);
    }

    @Test
    @DisplayName("다른 좌석·회원의 만료 선점은 새 선점 요청에서 정리하지 않는다")
    void hold_doesNotExpireUnrelatedHold() throws Exception {
        Long unrelatedSeatId = seatIdAt(1, 1);
        Long requestedSeatId = seatIdAt(1, 2);

        mvc.perform(holdBy(someoneElse, concertA, unrelatedSeatId)).andExpect(status().isOk());
        Long unrelatedHoldId = activeHold(concertA, unrelatedSeatId).getId();
        expireHold(concertA, unrelatedSeatId);

        mvc.perform(holdBy(me, concertA, requestedSeatId)).andExpect(status().isOk());
        flushAndClear();

        assertThat(seatHoldRepository.findById(unrelatedHoldId).orElseThrow().getStatus())
                .isEqualTo(SeatHoldStatus.HELD);
    }

    @Test
    @DisplayName("같은 회원의 다른 좌석 만료 선점은 새 선점 전에 정리한다")
    void hold_expiresRequestMembersStaleHold() throws Exception {
        Long expiredSeatId = seatIdAt(1, 1);
        Long requestedSeatId = seatIdAt(1, 2);

        mvc.perform(holdBy(me, concertA, expiredSeatId)).andExpect(status().isOk());
        Long expiredHoldId = activeHold(concertA, expiredSeatId).getId();
        expireHold(concertA, expiredSeatId);

        mvc.perform(holdBy(me, concertA, requestedSeatId)).andExpect(status().isOk());
        flushAndClear();

        assertThat(seatHoldRepository.findById(expiredHoldId).orElseThrow().getStatus())
                .isEqualTo(SeatHoldStatus.EXPIRED);
        assertThat(activeHold(concertA, requestedSeatId).getMember().getId()).isEqualTo(me);
    }

    @Test
    @DisplayName("만료된 선점은 좌석 목록에서 예매 가능으로 보인다")
    void expiredHold_readsAsAvailableInSeatList() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(someoneElse, concertA, seatId)).andExpect(status().isOk());
        expireHold(concertA, seatId);

        mvc.perform(seatsOf(concertA))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.seats[0].status").value("AVAILABLE"))
                .andExpect(jsonPath("$.availableCount").value(4));
    }

    @Test
    @DisplayName("만료된 선점은 구역 목록의 잔여석에도 다시 포함된다")
    void expiredHold_countedBackIntoSectionAvailableCount() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(someoneElse, concertA, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(sectionsOf(concertA))
                .andExpect(jsonPath("$.sections[0].availableCount").value(3));

        expireHold(concertA, seatId);

        mvc.perform(sectionsOf(concertA))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.sections[0].availableCount").value(4))
                .andExpect(jsonPath("$.totalAvailableCount").value(4));
    }

    // ---------------------------------------------------------------- 선점 실패

    @Test
    @DisplayName("남이 선점 중인 좌석이면 409 를 반환한다")
    void hold_returnsConflictWhenHeldByOther() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(someoneElse, concertA, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(holdBy(me, concertA, seatId))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.errorMessage")
                        .value("이미 선택된 좌석입니다. (seatId=" + seatId + ")"))
                .andExpect(jsonPath("$.exception").value("SeatNotHoldableException"));
    }

    @Test
    @DisplayName("이미 팔린 좌석이면 409 를 반환한다")
    void hold_returnsConflictWhenSold() throws Exception {
        Long seatId = seatIdAt(1, 1);
        sell(concertA, seatId, someoneElse);
        flushAndClear();

        mvc.perform(holdBy(me, concertA, seatId))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.exception").value("SeatNotHoldableException"));
    }

    @Test
    @DisplayName("해제 시각이 지난 취소 좌석은 잡을 수 있다")
    void hold_allowsRevokedSeatAfterRelease() throws Exception {
        Long seatId = seatIdAt(1, 1);
        revoke(concertA, seatId, someoneElse, LocalDateTime.now().minusSeconds(1));
        flushAndClear();

        mvc.perform(holdBy(me, concertA, seatId))
                .andExpect(status().isOk());
        flushAndClear();

        assertThat(seatHoldRepository.findActive(concertA.getId(), seatId, LocalDateTime.now()))
                .isPresent();
    }

    @Test
    @DisplayName("해제 시각 전인 취소 좌석은 아무도 잡을 수 없다")
    void hold_rejectsRevokedSeatBeforeRelease() throws Exception {
        Long seatId = seatIdAt(1, 2);
        revoke(concertA, seatId, someoneElse, LocalDateTime.now().plusMinutes(10));
        flushAndClear();

        // 조회에서는 선점과 구분되지 않는 자리다. 여기서 막지 않으면 API 직접 호출로 뚫린다.
        mvc.perform(holdBy(me, concertA, seatId))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.exception").value("SeatNotHoldableException"));
    }

    @Test
    @DisplayName("예매 중이 아닌 공연이면 409 를 반환한다")
    void hold_returnsConflictWhenConcertNotOnSale() throws Exception {
        Long seatId = seatIdAt(1, 1);
        ReflectionTestUtils.setField(concertA, "status", ConcertStatus.SCHEDULED);
        concertRepository.save(concertA);
        flushAndClear();

        mvc.perform(holdBy(me, concertA, seatId))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.errorMessage")
                        .value("예매 중인 공연이 아닙니다. (concertId=" + concertA.getId()
                                + ", status=SCHEDULED)"))
                .andExpect(jsonPath("$.exception").value("ConcertNotOnSaleException"));
        flushAndClear();

        assertThat(seatHoldRepository.findActive(concertA.getId(), seatId, LocalDateTime.now()))
                .isEmpty();
    }

    @Test
    @DisplayName("이미 이 공연의 티켓을 보유한 회원이면 409 를 반환한다")
    void hold_returnsConflictWhenAlreadyReserved() throws Exception {
        Long ownedSeatId = seatIdAt(1, 1);
        Long anotherSeatId = seatIdAt(1, 2);
        reservationRepository.save(Reservation.builder()
                .concert(concertA)
                .member(memberRepository.getReferenceById(me))
                .seat(seatRepository.getReferenceById(ownedSeatId))
                .build());
        flushAndClear();

        mvc.perform(holdBy(me, concertA, anotherSeatId))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.errorMessage")
                        .value("이미 이 공연의 티켓을 보유하고 있습니다. (concertId=" + concertA.getId() + ")"))
                .andExpect(jsonPath("$.exception").value("AlreadyReservedException"));
        flushAndClear();

        assertThat(seatHoldRepository.findActive(concertA.getId(), anotherSeatId, LocalDateTime.now()))
                .isEmpty();
    }

    @Test
    @DisplayName("존재하지 않는 좌석이면 404 를 반환한다")
    void hold_returnsNotFoundWhenSeatMissing() throws Exception {
        long missingSeatId = 999_999L;

        mvc.perform(post(SEAT_PATH + "/{seatId}/hold", missingSeatId)
                        .param("concertId", String.valueOf(concertA.getId()))
                        .with(Authenticated.as(me)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorMessage")
                        .value("존재하지 않는 좌석입니다. (seatId=" + missingSeatId + ")"))
                .andExpect(jsonPath("$.exception").value("SeatNotFoundException"));
    }

    @Test
    @DisplayName("존재하지 않는 공연이면 404 를 반환한다")
    void hold_returnsNotFoundWhenConcertMissing() throws Exception {
        mvc.perform(post(SEAT_PATH + "/{seatId}/hold", seatIdAt(1, 1))
                        .param("concertId", "999999")
                        .with(Authenticated.as(me)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.exception").value("ConcertNotFoundException"));
    }

    @Test
    @DisplayName("토큰이 없으면 401 을 반환하고 아무것도 선점되지 않는다")
    void hold_returnsUnauthorizedWhenTokenMissing() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(post(SEAT_PATH + "/{seatId}/hold", seatId)
                        .param("concertId", String.valueOf(concertA.getId())))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorMessage").value(AuthErrorCode.TOKEN_INVALID.getMessage()))
                .andExpect(jsonPath("$.exception").value("TokenInvalidException"));
        flushAndClear();

        assertThat(seatHoldRepository.findActive(concertA.getId(), seatId, LocalDateTime.now()))
                .isEmpty();
    }

    @Test
    @DisplayName("토큰의 sub 가 회원 id 가 아니면 401 을 반환한다")
    void hold_returnsUnauthorizedWhenSubjectIsNotMemberId() throws Exception {
        // 우리가 발급한 토큰의 sub 는 항상 회원 id 다. 아니면 우리 토큰이 아니다.
        mvc.perform(post(SEAT_PATH + "/{seatId}/hold", seatIdAt(1, 1))
                        .param("concertId", String.valueOf(concertA.getId()))
                        .with(Authenticated.asSubject("not-a-number")))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.exception").value("TokenInvalidException"));
    }

    // ---------------------------------------------------------------- 헬퍼

    private MockHttpServletRequestBuilder holdBy(long memberId, Concert concert, Long seatId) {
        return post(SEAT_PATH + "/{seatId}/hold", seatId)
                .param("concertId", String.valueOf(concert.getId()))
                .with(Authenticated.as(memberId));
    }

    private MockHttpServletRequestBuilder seatsOf(Concert concert) {
        return get(SEAT_PATH)
                .param("concertId", String.valueOf(concert.getId()))
                .param("sectionId", String.valueOf(section.getId()));
    }

    private MockHttpServletRequestBuilder sectionsOf(Concert concert) {
        return get(SECTION_PATH).param("concertId", String.valueOf(concert.getId()));
    }

    private SeatHold activeHold(Concert concert, Long seatId) {
        return seatHoldRepository.findActive(concert.getId(), seatId, LocalDateTime.now())
                .orElseThrow(() -> new AssertionError("유효한 선점이 없다. seatId=" + seatId));
    }

    /** 좌석을 팔린 것으로 만든다. 주문 확정 API 가 아직 없어 행을 직접 넣는다. */
    private void sell(Concert concert, Long seatId, long memberId) {
        reservationRepository.save(Reservation.builder()
                .concert(concert)
                .member(memberRepository.getReferenceById(memberId))
                .seat(seatRepository.getReferenceById(seatId))
                .build());
    }

    /**
     * 좌석을 취소된 적이 있는(회수된) 것으로 만든다. 취소 API 가 아직 없어 만들고 바로 취소한다.
     *
     * <p>{@code seatReleaseAt} 을 직접 받는다. 실제 취소는 3분 1초에서 15분 사이의 난수를 뽑지만,
     * 여기서 보는 것은 "그 시각 전후에 어떻게 보이는가" 라 값을 고정해야 한다.
     */
    private void revoke(Concert concert, Long seatId, long memberId, LocalDateTime seatReleaseAt) {
        Reservation reservation = reservationRepository.save(Reservation.builder()
                .concert(concert)
                .member(memberRepository.getReferenceById(memberId))
                .seat(seatRepository.getReferenceById(seatId))
                .build());
        reservation.cancel(LocalDateTime.now(), seatReleaseAt);
    }

    private Long seatIdAt(int seatNo, int seatCol) {
        return seatRepository.findAllBySectionIdOrderBySeatNoAscSeatColAsc(section.getId()).stream()
                .filter(seat -> seat.getSeatNo() == seatNo && seat.getSeatCol() == seatCol)
                .findFirst()
                .orElseThrow()
                .getId();
    }

    /** 선점을 이미 지난 것으로 만든다. 시계를 갈아 끼울 수 없어 만료 시각을 과거로 쓴다. */
    private void expireHold(Concert concert, Long seatId) {
        setExpiresAt(activeHold(concert, seatId).getId(), LocalDateTime.now().minusMinutes(1));
        flushAndClear();
    }

    private void setExpiresAt(Long holdId, LocalDateTime expiresAt) {
        SeatHold hold = seatHoldRepository.findById(holdId).orElseThrow();
        ReflectionTestUtils.setField(hold, "expiresAt", expiresAt);
        seatHoldRepository.save(hold);
    }

    private Concert saveConcert(String title, LocalDateTime startDate) {
        Concert concert = concertRepository.save(Concert.builder()
                .title(title)
                .genre(ConcertGenre.CONCERT)
                .ageRating(AgeRating.ALL)
                .startDate(startDate)
                .endDate(startDate.plusHours(3))
                // 선점은 openAt <= now < startDate - 2h 안에서만 성립한다. 오픈은 이미 지났어야 한다.
                .openAt(LocalDateTime.now().minusDays(1))
                .venue(venue)
                .build());
        // 선점은 예매 중인 공연만 허용하므로, 등록 직후의 SCHEDULED 그대로면 이 테스트의 선점 호출이 다 막힌다.
        ReflectionTestUtils.setField(concert, "status", ConcertStatus.ON_SALE);
        return concert;
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
