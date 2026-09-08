package com.ssafy.timo.domain.seat;

import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.SeatPosition;
import com.ssafy.timo.domain.seat.entity.SeatStatus;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.seat.repository.SeatRepository;
import com.ssafy.timo.domain.seat.repository.SectionRepository;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.global.security.exception.AuthErrorCode;
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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 좌석 선점 API 통합 테스트.
 *
 * <p>요청자는 인증이 아직 없어 {@code X-Member-Id} 헤더로 흉내 낸다
 * ({@code MockCurrentMemberProvider}). 인증이 붙으면 이 헤더만 사라지고 검증 내용은 그대로다.
 *
 * <p><b>동시 선점은 여기서 검증하지 않는다.</b> {@code @IntegrationTest} 가 테스트 전체를 한
 * 트랜잭션으로 묶으므로 두 요청이 서로의 행 잠금을 기다리는 상황을 만들 수 없다. 잠금이 실제로
 * 걸리는지는 생성 SQL 의 {@code for update} 로 확인했고, 스레드를 띄우는 동시성 테스트는
 * 트랜잭션 경계를 따로 잡아야 해서 별도 과제로 남긴다.
 *
 * <p>만료는 시계를 돌리지 않고 {@code held_until} 을 과거로 직접 써서 만든다. 컨텍스트를 공유하는
 * 규약 때문에 {@code Clock} 빈을 갈아 끼울 수 없다.
 */
@IntegrationTest
class SeatHoldApiIntegrationTest {

    private static final String SEAT_PATH = "/api/v1/seats";
    private static final String SECTION_PATH = "/api/v1/sections";
    private static final String MEMBER_HEADER = "X-Member-Id";

    private static final long ME = 1L;
    private static final long SOMEONE_ELSE = 2L;

    @Autowired
    private MockMvc mvc;

    @Autowired
    private SectionRepository sectionRepository;

    @Autowired
    private SeatRepository seatRepository;

    @Autowired
    private VenueRepository venueRepository;

    @Autowired
    private EntityManager em;

    private Long venueId;
    private Section section;

    @BeforeEach
    void setUpFixtures() {
        venueId = venueRepository.save(Venue.builder()
                .name("고척돔")
                .address("서울시 구로구 경인로 430")
                .totalSeatCount(16000)
                .build()).getId();

        section = saveSection("1층 A블록", 150000, 2, 2);
        flushAndClear();
    }

    // ---------------------------------------------------------------- 선점 성공

    @Test
    @DisplayName("좌석을 선점하면 200 과 함께 만료 시각을 5분 뒤로 알려준다")
    void hold_returnsOkWithExpiryFiveMinutesLater() throws Exception {
        Long seatId = seatIdAt(1, 1);
        LocalDateTime before = LocalDateTime.now();

        String heldUntil = mvc.perform(holdBy(ME, seatId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.seatId").value(seatId.intValue()))
                .andExpect(jsonPath("$.sectionId").value(section.getId().intValue()))
                .andExpect(jsonPath("$.sectionName").value("1층 A블록"))
                .andExpect(jsonPath("$.seatNo").value(1))
                .andExpect(jsonPath("$.seatCol").value(1))
                .andExpect(jsonPath("$.status").value("RESERVED"))
                .andExpect(jsonPath("$.releasedSeatId").isEmpty())
                .andReturn().getResponse().getContentAsString()
                .replaceAll(".*\"heldUntil\":\"([^\"]+)\".*", "$1");

        // 시계를 고정할 수 없으므로 5분 전후 여유를 두고 본다.
        assertThat(LocalDateTime.parse(heldUntil))
                .isAfter(before.plusMinutes(4).plusSeconds(50))
                .isBefore(before.plusMinutes(5).plusSeconds(10));
    }

    @Test
    @DisplayName("선점하면 좌석이 RESERVED 로 저장되고 누가 언제까지 잡았는지 기록된다")
    void hold_persistsHolderAndExpiry() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(ME, seatId)).andExpect(status().isOk());
        flushAndClear();

        Seat saved = seatRepository.findById(seatId).orElseThrow();
        assertThat(saved.getStatus()).isEqualTo(SeatStatus.RESERVED);
        assertThat(saved.getHeldByMemberId()).isEqualTo(ME);
        assertThat(saved.getHeldUntil()).isAfter(LocalDateTime.now());
    }

    @Test
    @DisplayName("선점한 좌석은 좌석 목록에서 RESERVED 로 보이고 잔여석에서 빠진다")
    void hold_reflectedInSeatListAndAvailableCount() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(ME, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(get(SEAT_PATH).param("sectionId", String.valueOf(section.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.seatCount").value(4))
                .andExpect(jsonPath("$.availableCount").value(3))
                .andExpect(jsonPath("$.seats[0].status").value("RESERVED"));

        mvc.perform(get(SECTION_PATH).param("venueId", String.valueOf(venueId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.sections[0].availableCount").value(3));
    }

    // ---------------------------------------------------------------- 한 계정 동시 하나

    @Test
    @DisplayName("새 좌석을 선점하면 이전 선점이 풀리고 어디가 풀렸는지 알려준다")
    void hold_releasesPreviousHoldOfSameMember() throws Exception {
        Long first = seatIdAt(1, 1);
        Long second = seatIdAt(1, 2);

        mvc.perform(holdBy(ME, first)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(holdBy(ME, second))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.seatId").value(second.intValue()))
                .andExpect(jsonPath("$.releasedSeatId").value(first.intValue()));
        flushAndClear();

        assertThat(seatRepository.findById(first).orElseThrow().getStatus())
                .isEqualTo(SeatStatus.AVAILABLE);
        assertThat(seatRepository.findById(first).orElseThrow().getHeldByMemberId()).isNull();
        assertThat(seatRepository.findById(second).orElseThrow().getStatus())
                .isEqualTo(SeatStatus.RESERVED);
    }

    @Test
    @DisplayName("남의 선점은 내가 새로 선점해도 풀리지 않는다")
    void hold_doesNotReleaseOtherMembersHold() throws Exception {
        Long theirs = seatIdAt(1, 1);
        Long mine = seatIdAt(1, 2);

        mvc.perform(holdBy(SOMEONE_ELSE, theirs)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(holdBy(ME, mine))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.releasedSeatId").isEmpty());
        flushAndClear();

        assertThat(seatRepository.findById(theirs).orElseThrow().getStatus())
                .isEqualTo(SeatStatus.RESERVED);
    }

    @Test
    @DisplayName("이미 내가 잡은 좌석을 다시 선점하면 만료 시각만 미뤄진다")
    void hold_extendsExpiryWhenAlreadyMine() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(ME, seatId)).andExpect(status().isOk());
        flushAndClear();

        // 만료가 임박한 상태로 만들어, 갱신이 실제로 일어나는지 본다.
        LocalDateTime almostExpired = LocalDateTime.now().plusSeconds(10);
        setHeldUntil(seatId, almostExpired);
        flushAndClear();

        mvc.perform(holdBy(ME, seatId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.releasedSeatId").isEmpty());
        flushAndClear();

        assertThat(seatRepository.findById(seatId).orElseThrow().getHeldUntil())
                .isAfter(almostExpired);
    }

    // ---------------------------------------------------------------- 만료

    @Test
    @DisplayName("만료된 선점은 다른 회원이 인수할 수 있다")
    void hold_takesOverExpiredHold() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(SOMEONE_ELSE, seatId)).andExpect(status().isOk());
        expireHold(seatId);

        mvc.perform(holdBy(ME, seatId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.seatId").value(seatId.intValue()));
        flushAndClear();

        assertThat(seatRepository.findById(seatId).orElseThrow().getHeldByMemberId()).isEqualTo(ME);
    }

    @Test
    @DisplayName("만료된 선점은 좌석 목록에서 예매 가능으로 보인다")
    void expiredHold_readsAsAvailableInSeatList() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(SOMEONE_ELSE, seatId)).andExpect(status().isOk());
        expireHold(seatId);

        // status 컬럼은 아직 RESERVED 다. 그걸 그대로 내려주면 만료된 자리를 아무도 못 산다.
        assertThat(seatRepository.findById(seatId).orElseThrow().getStatus())
                .isEqualTo(SeatStatus.RESERVED);

        mvc.perform(get(SEAT_PATH).param("sectionId", String.valueOf(section.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.seats[0].status").value("AVAILABLE"))
                .andExpect(jsonPath("$.availableCount").value(4));
    }

    @Test
    @DisplayName("만료된 선점은 구역 목록의 잔여석에도 다시 포함된다")
    void expiredHold_countedBackIntoSectionAvailableCount() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(SOMEONE_ELSE, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(get(SECTION_PATH).param("venueId", String.valueOf(venueId)))
                .andExpect(jsonPath("$.sections[0].availableCount").value(3));

        expireHold(seatId);

        mvc.perform(get(SECTION_PATH).param("venueId", String.valueOf(venueId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.sections[0].availableCount").value(4))
                .andExpect(jsonPath("$.totalAvailableCount").value(4));
    }

    // ---------------------------------------------------------------- 선점 실패

    @Test
    @DisplayName("남이 선점 중인 좌석이면 409 를 반환한다")
    void hold_returnsConflictWhenHeldByOther() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(SOMEONE_ELSE, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(holdBy(ME, seatId))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.errorMessage")
                        .value("이미 선택된 좌석입니다. (seatId=" + seatId + ")"))
                .andExpect(jsonPath("$.exception").value("SeatNotHoldableException"));
    }

    @Test
    @DisplayName("이미 결제까지 끝난 좌석이면 409 를 반환하고 만료 개념이 적용되지 않는다")
    void hold_returnsConflictWhenOccupied() throws Exception {
        Long seatId = seatIdAt(1, 1);
        setStatus(seatId, SeatStatus.OCCUPIED);
        flushAndClear();

        mvc.perform(holdBy(ME, seatId))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.exception").value("SeatNotHoldableException"));
    }

    @Test
    @DisplayName("존재하지 않는 좌석이면 404 를 반환한다")
    void hold_returnsNotFoundWhenSeatMissing() throws Exception {
        long missingSeatId = 999_999L;

        mvc.perform(post(SEAT_PATH + "/{seatId}/hold", missingSeatId)
                        .header(MEMBER_HEADER, ME))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorMessage")
                        .value("존재하지 않는 좌석입니다. (seatId=" + missingSeatId + ")"))
                .andExpect(jsonPath("$.exception").value("SeatNotFoundException"));
    }

    @Test
    @DisplayName("요청자를 특정할 수 없으면 401 을 반환하고 아무것도 선점되지 않는다")
    void hold_returnsUnauthorizedWhenMemberHeaderMissing() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(post(SEAT_PATH + "/{seatId}/hold", seatId))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorMessage").value(AuthErrorCode.TOKEN_INVALID.getMessage()))
                .andExpect(jsonPath("$.exception").value("TokenInvalidException"));
        flushAndClear();

        assertThat(seatRepository.findById(seatId).orElseThrow().getStatus())
                .isEqualTo(SeatStatus.AVAILABLE);
    }

    @Test
    @DisplayName("요청자 헤더가 숫자가 아니면 401 을 반환한다")
    void hold_returnsUnauthorizedWhenMemberHeaderMalformed() throws Exception {
        mvc.perform(post(SEAT_PATH + "/{seatId}/hold", seatIdAt(1, 1))
                        .header(MEMBER_HEADER, "not-a-number"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.exception").value("TokenInvalidException"));
    }

    // ---------------------------------------------------------------- 헬퍼

    private MockHttpServletRequestBuilder holdBy(long memberId, Long seatId) {
        return post(SEAT_PATH + "/{seatId}/hold", seatId).header(MEMBER_HEADER, memberId);
    }

    private Long seatIdAt(int seatNo, int seatCol) {
        return seatRepository.findAllBySectionIdOrderBySeatNoAscSeatColAsc(section.getId()).stream()
                .filter(seat -> seat.getSeatNo() == seatNo && seat.getSeatCol() == seatCol)
                .findFirst()
                .orElseThrow()
                .getId();
    }

    /** 선점을 이미 지난 것으로 만든다. 시계를 갈아 끼울 수 없어 만료 시각을 과거로 쓴다. */
    private void expireHold(Long seatId) {
        setHeldUntil(seatId, LocalDateTime.now().minusMinutes(1));
        flushAndClear();
    }

    private void setHeldUntil(Long seatId, LocalDateTime heldUntil) {
        Seat seat = seatRepository.findById(seatId).orElseThrow();
        ReflectionTestUtils.setField(seat, "heldUntil", heldUntil);
        seatRepository.save(seat);
    }

    /** 상태 전이 API 가 아직 없어 직접 바꾼다. */
    private void setStatus(Long seatId, SeatStatus status) {
        Seat seat = seatRepository.findById(seatId).orElseThrow();
        ReflectionTestUtils.setField(seat, "status", status);
        seatRepository.save(seat);
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
                .venue(venueRepository.getReferenceById(venueId))
                .build());

        seatRepository.saveAll(saved.createSeats(positions));
        return saved;
    }

    private void flushAndClear() {
        em.flush();
        em.clear();
    }
}
