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
 * 좌석 선점 취소 API 통합 테스트.
 *
 * <p>요청자는 인증이 아직 없어 {@code X-Member-Id} 헤더로 흉내 낸다
 * ({@code MockCurrentMemberProvider}). 인증이 붙으면 이 헤더만 사라지고 검증 내용은 그대로다.
 *
 * <p>선점은 실제 API 로 만든다. 취소가 선점 API 가 남긴 상태를 정확히 되돌리는지가 관심사이므로,
 * 선점 상태를 손으로 만들면 검증이 헐거워진다.
 *
 * <p>동시성은 {@link SeatHoldApiIntegrationTest} 와 같은 이유로 여기서 검증하지 않는다. 만료 역시
 * 시계를 돌리지 않고 {@code held_until} 을 과거로 직접 써서 만든다.
 */
@IntegrationTest
class SeatHoldCancelApiIntegrationTest {

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

    // ---------------------------------------------------------------- 취소 성공

    @Test
    @DisplayName("내가 잡은 좌석의 선점을 취소하면 200 과 함께 풀린 좌석 정보를 알려준다")
    void cancelHold_returnsOkWithReleasedSeat() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(ME, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(cancelBy(ME, seatId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.seatId").value(seatId.intValue()))
                .andExpect(jsonPath("$.sectionId").value(section.getId().intValue()))
                .andExpect(jsonPath("$.sectionName").value("1층 A블록"))
                .andExpect(jsonPath("$.seatNo").value(1))
                .andExpect(jsonPath("$.seatCol").value(1))
                .andExpect(jsonPath("$.status").value("AVAILABLE"))
                // 선점 응답에만 있는 필드다. 취소 뒤에는 의미가 없어 싣지 않는다.
                .andExpect(jsonPath("$.heldUntil").doesNotExist())
                .andExpect(jsonPath("$.releasedSeatId").doesNotExist())
                .andExpect(jsonPath("$.heldByMemberId").doesNotExist());
    }

    @Test
    @DisplayName("취소하면 좌석이 AVAILABLE 로 저장되고 선점 흔적이 지워진다")
    void cancelHold_persistsReleasedState() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(ME, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(cancelBy(ME, seatId)).andExpect(status().isOk());
        flushAndClear();

        Seat saved = seatRepository.findById(seatId).orElseThrow();
        assertThat(saved.getStatus()).isEqualTo(SeatStatus.AVAILABLE);
        assertThat(saved.getHeldByMemberId()).isNull();
        assertThat(saved.getHeldUntil()).isNull();
    }

    @Test
    @DisplayName("취소한 좌석은 좌석 목록에서 AVAILABLE 로 보이고 잔여석에 다시 포함된다")
    void cancelHold_reflectedInSeatListAndAvailableCount() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(ME, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(get(SECTION_PATH).param("venueId", String.valueOf(venueId)))
                .andExpect(jsonPath("$.sections[0].availableCount").value(3));

        mvc.perform(cancelBy(ME, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(get(SEAT_PATH).param("sectionId", String.valueOf(section.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.seatCount").value(4))
                .andExpect(jsonPath("$.availableCount").value(4))
                .andExpect(jsonPath("$.seats[0].status").value("AVAILABLE"));

        mvc.perform(get(SECTION_PATH).param("venueId", String.valueOf(venueId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.sections[0].availableCount").value(4));
    }

    @Test
    @DisplayName("취소한 좌석은 다른 회원이 바로 선점할 수 있다")
    void cancelHold_allowsOtherMemberToHoldImmediately() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(ME, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(cancelBy(ME, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(holdBy(SOMEONE_ELSE, seatId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("RESERVED"));
        flushAndClear();

        assertThat(seatRepository.findById(seatId).orElseThrow().getHeldByMemberId())
                .isEqualTo(SOMEONE_ELSE);
    }

    @Test
    @DisplayName("취소는 다른 좌석의 선점에 영향을 주지 않는다")
    void cancelHold_doesNotTouchOtherSeats() throws Exception {
        Long mine = seatIdAt(1, 1);
        Long theirs = seatIdAt(1, 2);

        mvc.perform(holdBy(ME, mine)).andExpect(status().isOk());
        mvc.perform(holdBy(SOMEONE_ELSE, theirs)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(cancelBy(ME, mine)).andExpect(status().isOk());
        flushAndClear();

        Seat untouched = seatRepository.findById(theirs).orElseThrow();
        assertThat(untouched.getStatus()).isEqualTo(SeatStatus.RESERVED);
        assertThat(untouched.getHeldByMemberId()).isEqualTo(SOMEONE_ELSE);
    }

    // ---------------------------------------------------------------- 멱등

    @Test
    @DisplayName("아무도 잡지 않은 좌석을 취소해도 200 이고 아무것도 바뀌지 않는다")
    void cancelHold_isNoOpWhenSeatIsFree() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(cancelBy(ME, seatId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.seatId").value(seatId.intValue()))
                .andExpect(jsonPath("$.status").value("AVAILABLE"));
        flushAndClear();

        Seat saved = seatRepository.findById(seatId).orElseThrow();
        assertThat(saved.getStatus()).isEqualTo(SeatStatus.AVAILABLE);
        assertThat(saved.getHeldByMemberId()).isNull();
    }

    @Test
    @DisplayName("이미 취소한 좌석을 다시 취소해도 200 이다")
    void cancelHold_isIdempotent() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(ME, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(cancelBy(ME, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(cancelBy(ME, seatId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("AVAILABLE"));
    }

    @Test
    @DisplayName("내 선점이 이미 만료된 좌석을 취소해도 200 으로 예매 가능이라고 답한다")
    void cancelHold_returnsOkWhenMyHoldExpired() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(ME, seatId)).andExpect(status().isOk());
        expireHold(seatId);

        // status 컬럼은 아직 RESERVED 다. 그걸 그대로 내려주면 화면이 자리가 막힌 줄 안다.
        mvc.perform(cancelBy(ME, seatId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("AVAILABLE"));
    }

    @Test
    @DisplayName("남의 선점이라도 만료됐으면 이미 빈 자리이므로 200 이다")
    void cancelHold_returnsOkWhenOthersHoldExpired() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(SOMEONE_ELSE, seatId)).andExpect(status().isOk());
        expireHold(seatId);

        mvc.perform(cancelBy(ME, seatId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("AVAILABLE"));
    }

    // ---------------------------------------------------------------- 취소 실패

    @Test
    @DisplayName("남이 선점 중인 좌석이면 403 을 반환하고 그 선점은 그대로다")
    void cancelHold_returnsForbiddenWhenHeldByOther() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(SOMEONE_ELSE, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(cancelBy(ME, seatId))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.errorMessage")
                        .value("본인이 선점한 좌석이 아닙니다. (seatId=" + seatId + ")"))
                .andExpect(jsonPath("$.exception").value("SeatHoldNotOwnedException"))
                // 누가 언제까지 잡았는지는 새어 나가면 안 된다.
                .andExpect(jsonPath("$.heldByMemberId").doesNotExist())
                .andExpect(jsonPath("$.heldUntil").doesNotExist());
        flushAndClear();

        Seat untouched = seatRepository.findById(seatId).orElseThrow();
        assertThat(untouched.getStatus()).isEqualTo(SeatStatus.RESERVED);
        assertThat(untouched.getHeldByMemberId()).isEqualTo(SOMEONE_ELSE);
    }

    @Test
    @DisplayName("이미 결제까지 끝난 좌석이면 403 을 반환하고 점유는 풀리지 않는다")
    void cancelHold_returnsForbiddenWhenOccupied() throws Exception {
        Long seatId = seatIdAt(1, 1);
        setStatus(seatId, SeatStatus.OCCUPIED);
        flushAndClear();

        mvc.perform(cancelBy(ME, seatId))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.exception").value("SeatHoldNotOwnedException"));
        flushAndClear();

        // 점유 해제는 선점 취소가 아니라 예매 취소의 몫이다.
        assertThat(seatRepository.findById(seatId).orElseThrow().getStatus())
                .isEqualTo(SeatStatus.OCCUPIED);
    }

    @Test
    @DisplayName("존재하지 않는 좌석이면 404 를 반환한다")
    void cancelHold_returnsNotFoundWhenSeatMissing() throws Exception {
        long missingSeatId = 999_999L;

        mvc.perform(delete(SEAT_PATH + "/{seatId}/hold", missingSeatId)
                        .header(MEMBER_HEADER, ME))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorMessage")
                        .value("존재하지 않는 좌석입니다. (seatId=" + missingSeatId + ")"))
                .andExpect(jsonPath("$.exception").value("SeatNotFoundException"));
    }

    @Test
    @DisplayName("요청자를 특정할 수 없으면 401 을 반환하고 선점은 그대로다")
    void cancelHold_returnsUnauthorizedWhenMemberHeaderMissing() throws Exception {
        Long seatId = seatIdAt(1, 1);

        mvc.perform(holdBy(ME, seatId)).andExpect(status().isOk());
        flushAndClear();

        mvc.perform(delete(SEAT_PATH + "/{seatId}/hold", seatId))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorMessage").value(AuthErrorCode.TOKEN_INVALID.getMessage()))
                .andExpect(jsonPath("$.exception").value("TokenInvalidException"));
        flushAndClear();

        assertThat(seatRepository.findById(seatId).orElseThrow().getStatus())
                .isEqualTo(SeatStatus.RESERVED);
    }

    @Test
    @DisplayName("요청자 헤더가 숫자가 아니면 401 을 반환한다")
    void cancelHold_returnsUnauthorizedWhenMemberHeaderMalformed() throws Exception {
        mvc.perform(delete(SEAT_PATH + "/{seatId}/hold", seatIdAt(1, 1))
                        .header(MEMBER_HEADER, "not-a-number"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.exception").value("TokenInvalidException"));
    }

    // ---------------------------------------------------------------- 헬퍼

    private MockHttpServletRequestBuilder holdBy(long memberId, Long seatId) {
        return post(SEAT_PATH + "/{seatId}/hold", seatId).header(MEMBER_HEADER, memberId);
    }

    private MockHttpServletRequestBuilder cancelBy(long memberId, Long seatId) {
        return delete(SEAT_PATH + "/{seatId}/hold", seatId).header(MEMBER_HEADER, memberId);
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
        Seat seat = seatRepository.findById(seatId).orElseThrow();
        ReflectionTestUtils.setField(seat, "heldUntil", LocalDateTime.now().minusMinutes(1));
        seatRepository.save(seat);
        flushAndClear();
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
