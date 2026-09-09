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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 좌석 점유(결제 확정) / 점유 해제(예매 취소) API 통합 테스트.
 *
 * <p>두 API 는 예매 도메인이 생기기 전까지 결제 확정과 예매 취소를 흉내 내는 임시 진입점이다.
 * 예매 도메인이 생기면 API 는 사라지고 서비스 메서드만 남지만, 여기서 검증하는 상태 전이 규칙은
 * 그때도 그대로다.
 *
 * <p>선점은 실제 API 로 만든다. 점유가 선점 API 가 남긴 상태 위에서만 성립하는지가 관심사다.
 * 요청자는 {@code X-Member-Id} 헤더로 흉내 낸다 ({@code MockCurrentMemberProvider}).
 *
 * <p>동시성과 만료는 {@link SeatHoldApiIntegrationTest} 와 같은 방식으로 다룬다.
 */
@IntegrationTest
class SeatOccupancyApiIntegrationTest {

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

    // ================================================================ 점유 (결제 확정)

    @Test
    @DisplayName("내가 선점한 좌석을 점유하면 200 과 함께 OCCUPIED 좌석 정보를 알려준다")
    void occupy_returnsOkWithOccupiedSeat() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(ME, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(occupyBy(ME, seatId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.seatId").value(seatId.intValue()))
                .andExpect(jsonPath("$.sectionId").value(section.getId().intValue()))
                .andExpect(jsonPath("$.sectionName").value("1층 A블록"))
                .andExpect(jsonPath("$.seatNo").value(1))
                .andExpect(jsonPath("$.seatCol").value(1))
                .andExpect(jsonPath("$.status").value("OCCUPIED"))
                // 점유에는 만료가 없다. 선점 응답에만 있는 필드는 싣지 않는다.
                .andExpect(jsonPath("$.heldUntil").doesNotExist())
                .andExpect(jsonPath("$.releasedSeatId").doesNotExist())
                .andExpect(jsonPath("$.heldByMemberId").doesNotExist());
    }

    @Test
    @DisplayName("점유하면 OCCUPIED 로 저장되고 소유자는 남고 만료 시각은 지워진다")
    void occupy_persistsOwnerWithoutExpiry() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(ME, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(occupyBy(ME, seatId)).andExpect(status().isOk());
        flushAndClear();

        Seat saved = seatRepository.findById(seatId).orElseThrow();
        assertThat(saved.getStatus()).isEqualTo(SeatStatus.OCCUPIED);
        assertThat(saved.getHeldByMemberId()).isEqualTo(ME);
        // 만료 시각이 남아 있으면 읽는 쪽이 "만료된 선점"으로 오판할 여지가 생긴다.
        assertThat(saved.getHeldUntil()).isNull();
    }

    @Test
    @DisplayName("점유한 좌석은 좌석 목록에서 OCCUPIED 로 보이고 잔여석에서 빠진다")
    void occupy_reflectedInSeatListAndAvailableCount() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(ME, seatId)).andExpect(status().isOk());
        mvc.perform(occupyBy(ME, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(get(SEAT_PATH).param("sectionId", String.valueOf(section.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.seatCount").value(4))
                .andExpect(jsonPath("$.availableCount").value(3))
                .andExpect(jsonPath("$.seats[0].status").value("OCCUPIED"));

        mvc.perform(get(SECTION_PATH).param("venueId", String.valueOf(venueId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.sections[0].availableCount").value(3));
    }

    @Test
    @DisplayName("점유한 좌석은 시간이 지나도 만료되지 않아 다른 회원이 선점할 수 없다")
    void occupy_neverExpires() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(ME, seatId)).andExpect(status().isOk());
        mvc.perform(occupyBy(ME, seatId)).andExpect(status().isOk());
        flushAndClear();

        // 선점이었다면 만료로 인수될 시각을 과거로 써 본다. 점유는 이 값을 보지 않아야 한다.
        setHeldUntil(seatId, LocalDateTime.now().minusDays(1));
        flushAndClear();

        mvc.perform(holdBy(SOMEONE_ELSE, seatId))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.exception").value("SeatNotHoldableException"));
    }

    @Test
    @DisplayName("점유한 좌석은 선점 취소로 풀 수 없다")
    void occupy_cannotBeReleasedByHoldCancel() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(ME, seatId)).andExpect(status().isOk());
        mvc.perform(occupyBy(ME, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(cancelHoldBy(ME, seatId))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.exception").value("SeatHoldNotOwnedException"));
        flushAndClear();

        assertThat(seatRepository.findById(seatId).orElseThrow().getStatus())
                .isEqualTo(SeatStatus.OCCUPIED);
    }

    @Test
    @DisplayName("이미 내가 점유한 좌석을 다시 점유해도 200 이다")
    void occupy_isIdempotent() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(ME, seatId)).andExpect(status().isOk());
        mvc.perform(occupyBy(ME, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(occupyBy(ME, seatId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("OCCUPIED"));
    }

    @Test
    @DisplayName("점유는 내 다른 선점을 풀지 않는다")
    void occupy_doesNotTouchOtherSeats() throws Exception {
        Long first = seatIdAt(1, 1);
        Long second = seatIdAt(1, 2);

        mvc.perform(holdBy(ME, first)).andExpect(status().isOk());
        mvc.perform(holdBy(SOMEONE_ELSE, second)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(occupyBy(ME, first)).andExpect(status().isOk());
        flushAndClear();

        Seat untouched = seatRepository.findById(second).orElseThrow();
        assertThat(untouched.getStatus()).isEqualTo(SeatStatus.RESERVED);
        assertThat(untouched.getHeldByMemberId()).isEqualTo(SOMEONE_ELSE);
    }

    // ---------------------------------------------------------------- 점유 실패

    @Test
    @DisplayName("선점하지 않은 좌석을 점유하면 409 를 반환한다")
    void occupy_returnsConflictWhenSeatIsFree() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(occupyBy(ME, seatId))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.errorMessage")
                        .value("선점 상태가 아닌 좌석입니다. (seatId=" + seatId + ")"))
                .andExpect(jsonPath("$.exception").value("SeatNotHeldException"));
        flushAndClear();

        assertThat(seatRepository.findById(seatId).orElseThrow().getStatus())
                .isEqualTo(SeatStatus.AVAILABLE);
    }

    @Test
    @DisplayName("내 선점이 만료된 좌석을 점유하면 409 를 반환한다")
    void occupy_returnsConflictWhenMyHoldExpired() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(ME, seatId)).andExpect(status().isOk());
        expireHold(seatId);

        // 5분 안에 결제를 못 마쳤다. 만료된 선점 위에 결제를 얹어 주면 5분 규칙이 무의미하다.
        mvc.perform(occupyBy(ME, seatId))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.exception").value("SeatNotHeldException"));
        flushAndClear();

        assertThat(seatRepository.findById(seatId).orElseThrow().getStatus())
                .isNotEqualTo(SeatStatus.OCCUPIED);
    }

    @Test
    @DisplayName("남이 선점 중인 좌석을 점유하면 403 을 반환하고 그 선점은 그대로다")
    void occupy_returnsForbiddenWhenHeldByOther() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(SOMEONE_ELSE, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(occupyBy(ME, seatId))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.exception").value("SeatHoldNotOwnedException"))
                .andExpect(jsonPath("$.heldByMemberId").doesNotExist())
                .andExpect(jsonPath("$.heldUntil").doesNotExist());
        flushAndClear();

        Seat untouched = seatRepository.findById(seatId).orElseThrow();
        assertThat(untouched.getStatus()).isEqualTo(SeatStatus.RESERVED);
        assertThat(untouched.getHeldByMemberId()).isEqualTo(SOMEONE_ELSE);
    }

    @Test
    @DisplayName("남이 점유한 좌석을 점유하면 403 을 반환한다")
    void occupy_returnsForbiddenWhenOccupiedByOther() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(SOMEONE_ELSE, seatId)).andExpect(status().isOk());
        mvc.perform(occupyBy(SOMEONE_ELSE, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(occupyBy(ME, seatId))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.exception").value("SeatHoldNotOwnedException"));
        flushAndClear();

        assertThat(seatRepository.findById(seatId).orElseThrow().getHeldByMemberId())
                .isEqualTo(SOMEONE_ELSE);
    }

    @Test
    @DisplayName("존재하지 않는 좌석을 점유하면 404 를 반환한다")
    void occupy_returnsNotFoundWhenSeatMissing() throws Exception {
        long missingSeatId = 999_999L;

        mvc.perform(post(SEAT_PATH + "/{seatId}/occupancy", missingSeatId)
                        .header(MEMBER_HEADER, ME))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorMessage")
                        .value("존재하지 않는 좌석입니다. (seatId=" + missingSeatId + ")"))
                .andExpect(jsonPath("$.exception").value("SeatNotFoundException"));
    }

    @Test
    @DisplayName("요청자를 특정할 수 없으면 점유는 401 을 반환하고 선점은 그대로다")
    void occupy_returnsUnauthorizedWhenMemberHeaderMissing() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(ME, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(post(SEAT_PATH + "/{seatId}/occupancy", seatId))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorMessage").value(AuthErrorCode.TOKEN_INVALID.getMessage()))
                .andExpect(jsonPath("$.exception").value("TokenInvalidException"));
        flushAndClear();

        assertThat(seatRepository.findById(seatId).orElseThrow().getStatus())
                .isEqualTo(SeatStatus.RESERVED);
    }

    // ================================================================ 점유 해제 (예매 취소)

    @Test
    @DisplayName("내가 점유한 좌석을 해제하면 200 과 함께 AVAILABLE 좌석 정보를 알려준다")
    void releaseOccupancy_returnsOkWithReleasedSeat() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(ME, seatId)).andExpect(status().isOk());
        mvc.perform(occupyBy(ME, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(releaseBy(ME, seatId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.seatId").value(seatId.intValue()))
                .andExpect(jsonPath("$.sectionId").value(section.getId().intValue()))
                .andExpect(jsonPath("$.sectionName").value("1층 A블록"))
                .andExpect(jsonPath("$.seatNo").value(1))
                .andExpect(jsonPath("$.seatCol").value(1))
                .andExpect(jsonPath("$.status").value("AVAILABLE"))
                .andExpect(jsonPath("$.heldUntil").doesNotExist())
                .andExpect(jsonPath("$.heldByMemberId").doesNotExist());
    }

    @Test
    @DisplayName("해제하면 AVAILABLE 로 저장되고 소유자 흔적이 지워진다")
    void releaseOccupancy_persistsReleasedState() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(ME, seatId)).andExpect(status().isOk());
        mvc.perform(occupyBy(ME, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(releaseBy(ME, seatId)).andExpect(status().isOk());
        flushAndClear();

        Seat saved = seatRepository.findById(seatId).orElseThrow();
        assertThat(saved.getStatus()).isEqualTo(SeatStatus.AVAILABLE);
        assertThat(saved.getHeldByMemberId()).isNull();
        assertThat(saved.getHeldUntil()).isNull();
    }

    @Test
    @DisplayName("해제한 좌석은 잔여석에 다시 포함되고 다른 회원이 바로 선점할 수 있다")
    void releaseOccupancy_makesSeatSellableAgain() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(ME, seatId)).andExpect(status().isOk());
        mvc.perform(occupyBy(ME, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(releaseBy(ME, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(get(SECTION_PATH).param("venueId", String.valueOf(venueId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.sections[0].availableCount").value(4));

        mvc.perform(holdBy(SOMEONE_ELSE, seatId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("RESERVED"));
    }

    // ---------------------------------------------------------------- 해제 멱등

    @Test
    @DisplayName("아무도 잡지 않은 좌석을 해제해도 200 이고 아무것도 바뀌지 않는다")
    void releaseOccupancy_isNoOpWhenSeatIsFree() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(releaseBy(ME, seatId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("AVAILABLE"));
        flushAndClear();

        Seat saved = seatRepository.findById(seatId).orElseThrow();
        assertThat(saved.getStatus()).isEqualTo(SeatStatus.AVAILABLE);
        assertThat(saved.getHeldByMemberId()).isNull();
    }

    @Test
    @DisplayName("이미 해제한 좌석을 다시 해제해도 200 이다")
    void releaseOccupancy_isIdempotent() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(ME, seatId)).andExpect(status().isOk());
        mvc.perform(occupyBy(ME, seatId)).andExpect(status().isOk());
        mvc.perform(releaseBy(ME, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(releaseBy(ME, seatId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("AVAILABLE"));
    }

    @Test
    @DisplayName("만료된 선점만 남은 좌석을 해제해도 이미 빈 자리이므로 200 이다")
    void releaseOccupancy_returnsOkWhenOnlyExpiredHoldRemains() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(SOMEONE_ELSE, seatId)).andExpect(status().isOk());
        expireHold(seatId);

        mvc.perform(releaseBy(ME, seatId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("AVAILABLE"));
    }

    // ---------------------------------------------------------------- 해제 실패

    @Test
    @DisplayName("선점 중인 좌석(점유 아님)을 해제하면 409 를 반환하고 선점은 그대로다")
    void releaseOccupancy_returnsConflictWhenSeatIsOnlyHeld() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(ME, seatId)).andExpect(status().isOk());
        flushAndClear();

        // 결제도 안 된 좌석에 예매 취소가 들어온 것이다. 데이터가 어긋난 것이므로 조용히 넘기지 않는다.
        mvc.perform(releaseBy(ME, seatId))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.errorMessage")
                        .value("점유된 좌석이 아닙니다. (seatId=" + seatId + ")"))
                .andExpect(jsonPath("$.exception").value("SeatNotOccupiedException"));
        flushAndClear();

        assertThat(seatRepository.findById(seatId).orElseThrow().getStatus())
                .isEqualTo(SeatStatus.RESERVED);
    }

    @Test
    @DisplayName("남이 선점 중인 좌석을 해제해도 409 이고 그 선점은 그대로다")
    void releaseOccupancy_returnsConflictWhenHeldByOther() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(SOMEONE_ELSE, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(releaseBy(ME, seatId))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.exception").value("SeatNotOccupiedException"));
        flushAndClear();

        Seat untouched = seatRepository.findById(seatId).orElseThrow();
        assertThat(untouched.getStatus()).isEqualTo(SeatStatus.RESERVED);
        assertThat(untouched.getHeldByMemberId()).isEqualTo(SOMEONE_ELSE);
    }

    @Test
    @DisplayName("남이 점유한 좌석을 해제하면 403 을 반환하고 점유는 그대로다")
    void releaseOccupancy_returnsForbiddenWhenOccupiedByOther() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(SOMEONE_ELSE, seatId)).andExpect(status().isOk());
        mvc.perform(occupyBy(SOMEONE_ELSE, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(releaseBy(ME, seatId))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.errorMessage")
                        .value("본인이 점유한 좌석이 아닙니다. (seatId=" + seatId + ")"))
                .andExpect(jsonPath("$.exception").value("SeatOccupancyNotOwnedException"))
                .andExpect(jsonPath("$.heldByMemberId").doesNotExist());
        flushAndClear();

        Seat untouched = seatRepository.findById(seatId).orElseThrow();
        assertThat(untouched.getStatus()).isEqualTo(SeatStatus.OCCUPIED);
        assertThat(untouched.getHeldByMemberId()).isEqualTo(SOMEONE_ELSE);
    }

    @Test
    @DisplayName("존재하지 않는 좌석을 해제하면 404 를 반환한다")
    void releaseOccupancy_returnsNotFoundWhenSeatMissing() throws Exception {
        long missingSeatId = 999_999L;

        mvc.perform(delete(SEAT_PATH + "/{seatId}/occupancy", missingSeatId)
                        .header(MEMBER_HEADER, ME))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.exception").value("SeatNotFoundException"));
    }

    @Test
    @DisplayName("요청자를 특정할 수 없으면 해제는 401 을 반환하고 점유는 그대로다")
    void releaseOccupancy_returnsUnauthorizedWhenMemberHeaderMissing() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(ME, seatId)).andExpect(status().isOk());
        mvc.perform(occupyBy(ME, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(delete(SEAT_PATH + "/{seatId}/occupancy", seatId))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.exception").value("TokenInvalidException"));
        flushAndClear();

        assertThat(seatRepository.findById(seatId).orElseThrow().getStatus())
                .isEqualTo(SeatStatus.OCCUPIED);
    }

    @Test
    @DisplayName("요청자 헤더가 숫자가 아니면 401 을 반환한다")
    void releaseOccupancy_returnsUnauthorizedWhenMemberHeaderMalformed() throws Exception {
        mvc.perform(delete(SEAT_PATH + "/{seatId}/occupancy", seatIdAt(1, 1))
                        .header(MEMBER_HEADER, "not-a-number"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.exception").value("TokenInvalidException"));
    }

    // ---------------------------------------------------------------- 헬퍼

    private MockHttpServletRequestBuilder holdBy(long memberId, Long seatId) {
        return post(SEAT_PATH + "/{seatId}/hold", seatId).header(MEMBER_HEADER, memberId);
    }

    private MockHttpServletRequestBuilder cancelHoldBy(long memberId, Long seatId) {
        return delete(SEAT_PATH + "/{seatId}/hold", seatId).header(MEMBER_HEADER, memberId);
    }

    private MockHttpServletRequestBuilder occupyBy(long memberId, Long seatId) {
        return post(SEAT_PATH + "/{seatId}/occupancy", seatId).header(MEMBER_HEADER, memberId);
    }

    private MockHttpServletRequestBuilder releaseBy(long memberId, Long seatId) {
        return delete(SEAT_PATH + "/{seatId}/occupancy", seatId).header(MEMBER_HEADER, memberId);
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
