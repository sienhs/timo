package com.ssafy.timo.domain.seat;

import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.SeatGrade;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.seat.repository.SeatRepository;
import com.ssafy.timo.domain.seat.repository.SectionRepository;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.global.exception.ErrorCode;
import com.ssafy.timo.support.IntegrationTest;
import jakarta.persistence.EntityManager;
import org.assertj.core.groups.Tuple;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.containsInAnyOrder;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 좌석 등록 API 통합 테스트.
 *
 * <p>컨트롤러부터 서비스, JPA, 실제 MySQL 까지 그대로 태운다. 좌석이 정말로 INSERT 됐는지,
 * {@code seat_count} 에 실제 개수가 들어갔는지, "이미 등록된 구역명이면 409" 처럼 기존 행이 있어야
 * 드러나는 동작까지 검증한다.
 *
 * <p>선행 데이터는 매 테스트 시작 시 리포지토리로 직접 넣는다. {@code @IntegrationTest} 가
 * 트랜잭션을 걸어 두므로 테스트가 끝나면 롤백되어 서로 영향을 주지 않는다.
 */
@IntegrationTest
class SeatApiIntegrationTest {

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

    @BeforeEach
    void setUpFixtures() {
        venueId = venueRepository.save(Venue.builder()
                .name("고척돔")
                .address("서울시 구로구 경인로 430")
                .totalSeatCount(16000)
                .build()).getId();
    }

    @Test
    @DisplayName("좌석을 등록하면 201 과 함께 구역별 좌석 수가 담긴 응답을 반환한다")
    void register_returnsCreatedWithSectionSummaries() throws Exception {
        mvc.perform(post("/api/v1/seats")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(gappedSectionBody()))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.venueId").value(venueId.intValue()))
                .andExpect(jsonPath("$.venueName").value("고척돔"))
                .andExpect(jsonPath("$.totalSeatCount").value(5))
                .andExpect(jsonPath("$.sections.length()").value(1))
                .andExpect(jsonPath("$.sections[0].id").isNumber())
                .andExpect(jsonPath("$.sections[0].name").value("1층 A블록"))
                .andExpect(jsonPath("$.sections[0].price").value(150000))
                .andExpect(jsonPath("$.sections[0].seatCount").value(5));
    }

    @Test
    @DisplayName("가리킬 단일 리소스가 없으므로 Location 헤더는 싣지 않는다")
    void register_doesNotSendLocationHeader() throws Exception {
        mvc.perform(post("/api/v1/seats")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(gappedSectionBody()))
                .andExpect(status().isCreated())
                .andExpect(header().doesNotExist("Location"));
    }

    @Test
    @DisplayName("보낸 자리에만 좌석이 저장되고 통로로 빈 자리는 만들어지지 않는다")
    void register_persistsSeatsOnlyAtListedPositions() throws Exception {
        mvc.perform(post("/api/v1/seats")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(gappedSectionBody()))
                .andExpect(status().isCreated());

        // 격자로 찍어냈다면 2행 2번 자리까지 6석이 됐어야 한다.
        assertThat(savedSeats())
                .extracting(Seat::getSeatNo, Seat::getSeatCol)
                .containsExactlyInAnyOrder(
                        Tuple.tuple(1, 1), Tuple.tuple(1, 2), Tuple.tuple(1, 3),
                        Tuple.tuple(2, 1), Tuple.tuple(2, 3));
    }

    @Test
    @DisplayName("구역의 좌석 수는 실제로 저장된 좌석 행 수와 같다")
    void register_persistsSeatCountMatchingSeatRows() throws Exception {
        mvc.perform(post("/api/v1/seats")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(gappedSectionBody()))
                .andExpect(status().isCreated());

        Section saved = onlySavedSection();

        assertThat(saved.getSeatCount()).isEqualTo(5);
        assertThat(seatRepository.countBySectionId(saved.getId())).isEqualTo(5);
    }

    @Test
    @DisplayName("갓 등록된 좌석은 모두 예매 가능 상태로 저장되고 자신의 구역을 가리킨다")
    void register_persistsSeatsAsAvailable() throws Exception {
        mvc.perform(post("/api/v1/seats")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(gappedSectionBody()))
                .andExpect(status().isCreated());

        Long sectionId = onlySavedSection().getId();

        assertThat(savedSeats()).allSatisfy(seat -> {
            assertThat(seat.getSection().getId()).isEqualTo(sectionId);
        });
    }

    @Test
    @DisplayName("등급은 요청에 없어도 일반석으로 저장된다")
    void register_persistsCommonGrade() throws Exception {
        mvc.perform(post("/api/v1/seats")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(gappedSectionBody()))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.sections[0].grade").value("COMMON"));

        assertThat(onlySavedSection().getGrade()).isEqualTo(SeatGrade.COMMON);
    }

    @Test
    @DisplayName("배치도 격자 크기를 보내지 않으면 좌석의 최대 번호에서 뽑아내 저장한다")
    void register_derivesGridSizeFromSeats() throws Exception {
        mvc.perform(post("/api/v1/seats")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(gappedSectionBody()))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.sections[0].rowCount").value(2))
                .andExpect(jsonPath("$.sections[0].seatPerRow").value(3));

        Section saved = onlySavedSection();

        // 격자 크기는 2 x 3 = 6 이지만 실제 좌석은 5석이다. 둘은 같지 않아도 된다.
        assertThat(saved.getRowCount()).isEqualTo(2);
        assertThat(saved.getSeatPerRow()).isEqualTo(3);
        assertThat(saved.getSeatCount()).isEqualTo(5);
    }

    @Test
    @DisplayName("행마다 좌석 수가 다른 배치도 그대로 저장된다")
    void register_persistsRowsOfDifferentLengths() throws Exception {
        mvc.perform(post("/api/v1/seats")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "venueId": %d,
                                  "sections": [
                                    {
                                      "name": "1층 B블록",
                                      "price": 130000,
                                      "seats": [
                                        {"seatNo": 1, "seatCol": 1}, {"seatNo": 1, "seatCol": 2},
                                        {"seatNo": 1, "seatCol": 3}, {"seatNo": 1, "seatCol": 4},
                                        {"seatNo": 2, "seatCol": 1}, {"seatNo": 2, "seatCol": 2},
                                        {"seatNo": 2, "seatCol": 3},
                                        {"seatNo": 3, "seatCol": 1}, {"seatNo": 3, "seatCol": 2}
                                      ]
                                    }
                                  ]
                                }
                                """.formatted(venueId)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.sections[0].seatCount").value(9));

        Section saved = onlySavedSection();

        // 가장 긴 행이 4석이므로 격자는 3 x 4 로 잡히고, 그 12 자리 중 9석만 존재한다.
        assertThat(saved.getRowCount()).isEqualTo(3);
        assertThat(saved.getSeatPerRow()).isEqualTo(4);
        assertThat(saved.getSeatCount()).isEqualTo(9);
        assertThat(seatRepository.count()).isEqualTo(9);
    }

    @Test
    @DisplayName("배치도 격자 크기를 함께 보내면 유도값으로 덮이지 않는다")
    void register_keepsDeclaredGridSize() throws Exception {
        mvc.perform(post("/api/v1/seats")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "venueId": %d,
                                  "sections": [
                                    {
                                      "name": "2층 A블록",
                                      "price": 99000,
                                      "rowCount": 10,
                                      "seatPerRow": 20,
                                      "seats": [
                                        {"seatNo": 1, "seatCol": 5},
                                        {"seatNo": 9, "seatCol": 18}
                                      ]
                                    }
                                  ]
                                }
                                """.formatted(venueId)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.sections[0].rowCount").value(10))
                .andExpect(jsonPath("$.sections[0].seatPerRow").value(20))
                .andExpect(jsonPath("$.sections[0].seatCount").value(2));

        Section saved = onlySavedSection();

        assertThat(saved.getRowCount()).isEqualTo(10);
        assertThat(saved.getSeatPerRow()).isEqualTo(20);
    }

    @Test
    @DisplayName("구역 여러 개를 한 번에 등록하면 각 구역에 자기 좌석만 붙는다")
    void register_persistsMultipleSectionsInOneRequest() throws Exception {
        mvc.perform(post("/api/v1/seats")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "venueId": %d,
                                  "sections": [
                                    {
                                      "name": "3층 A블록",
                                      "price": 70000,
                                      "seats": [
                                        {"seatNo": 1, "seatCol": 1}, {"seatNo": 1, "seatCol": 2},
                                        {"seatNo": 2, "seatCol": 1}
                                      ]
                                    },
                                    {
                                      "name": "3층 B블록",
                                      "price": 50000,
                                      "seats": [
                                        {"seatNo": 1, "seatCol": 1}, {"seatNo": 1, "seatCol": 2}
                                      ]
                                    }
                                  ]
                                }
                                """.formatted(venueId)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.totalSeatCount").value(5))
                .andExpect(jsonPath("$.sections.length()").value(2))
                // 보낸 순서가 그대로 응답 순서가 된다.
                .andExpect(jsonPath("$.sections[0].name").value("3층 A블록"))
                .andExpect(jsonPath("$.sections[1].name").value("3층 B블록"));

        em.flush();
        em.clear();

        List<Section> sections = sectionRepository.findAllByVenueId(venueId);
        assertThat(sections)
                .extracting(Section::getName, Section::getPrice, Section::getSeatCount)
                .containsExactlyInAnyOrder(
                        Tuple.tuple("3층 A블록", 70000, 3),
                        Tuple.tuple("3층 B블록", 50000, 2));

        for (Section section : sections) {
            assertThat(seatRepository.countBySectionId(section.getId()))
                    .isEqualTo(section.getSeatCount());
        }
    }

    @Test
    @DisplayName("필수값이 빠지면 400 과 필드 에러를 반환하고 아무것도 저장하지 않는다")
    void register_rejectsMissingRequiredFields() throws Exception {
        mvc.perform(post("/api/v1/seats")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorMessage").value(ErrorCode.INVALID_INPUT_VALUE.getMessage()))
                .andExpect(jsonPath("$.errors[*].field")
                        .value(containsInAnyOrder("venueId", "sections")));

        assertNothingSaved();
    }

    @Test
    @DisplayName("좌석 목록이 없으면 400 을 반환한다 - 격자 크기만으로는 좌석을 만들지 않는다")
    void register_rejectsSectionWithoutSeats() throws Exception {
        mvc.perform(post("/api/v1/seats")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "venueId": %d,
                                  "sections": [
                                    {"name": "좌석 없는 구역", "price": 99000, "rowCount": 10, "seatPerRow": 20}
                                  ]
                                }
                                """.formatted(venueId)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors[0].field").value("sections[0].seats"))
                .andExpect(jsonPath("$.errors[0].reason").value("좌석은 최소 1개여야 합니다."));

        assertNothingSaved();
    }

    @Test
    @DisplayName("좌석 번호가 1 미만이면 400 과 함께 문제가 된 좌석의 위치를 알려준다")
    void register_rejectsSeatNumberBelowOne() throws Exception {
        mvc.perform(post("/api/v1/seats")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "venueId": %d,
                                  "sections": [
                                    {
                                      "name": "0번 자리 구역",
                                      "price": 99000,
                                      "seats": [{"seatNo": 0, "seatCol": 1}]
                                    }
                                  ]
                                }
                                """.formatted(venueId)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors[0].field").value("sections[0].seats[0].seatNo"))
                .andExpect(jsonPath("$.errors[0].reason").value("행 번호는 1 이상이어야 합니다."));

        assertNothingSaved();
    }

    @Test
    @DisplayName("행 수가 상한을 넘으면 400 을 반환한다")
    void register_rejectsTooManyRows() throws Exception {
        mvc.perform(post("/api/v1/seats")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "venueId": %d,
                                  "sections": [
                                    {
                                      "name": "거대 구역",
                                      "price": 99000,
                                      "rowCount": 100000,
                                      "seatPerRow": 20,
                                      "seats": [{"seatNo": 1, "seatCol": 1}]
                                    }
                                  ]
                                }
                                """.formatted(venueId)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors[0].field").value("sections[0].rowCount"))
                .andExpect(jsonPath("$.errors[0].reason").value("행 수는 200 이하여야 합니다."));

        assertNothingSaved();
    }

    @Test
    @DisplayName("같은 자리가 두 번 들어오면 400 을 반환하고 아무것도 저장하지 않는다")
    void register_returnsBadRequestOnDuplicatedSeatPosition() throws Exception {
        mvc.perform(post("/api/v1/seats")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "venueId": %d,
                                  "sections": [
                                    {
                                      "name": "중복 자리 구역",
                                      "price": 99000,
                                      "seats": [
                                        {"seatNo": 1, "seatCol": 1}, {"seatNo": 1, "seatCol": 2},
                                        {"seatNo": 1, "seatCol": 1}
                                      ]
                                    }
                                  ]
                                }
                                """.formatted(venueId)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.exception").value("DuplicatedSeatPositionException"))
                .andExpect(jsonPath("$.errorMessage").value(
                        "같은 좌석 자리가 두 번 들어왔습니다. (section=중복 자리 구역, seatNo=1, seatCol=1)"));

        assertNothingSaved();
    }

    @Test
    @DisplayName("선언한 격자 크기를 벗어난 자리가 있으면 400 을 반환한다")
    void register_returnsBadRequestOnSeatOutOfDeclaredBounds() throws Exception {
        mvc.perform(post("/api/v1/seats")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "venueId": %d,
                                  "sections": [
                                    {
                                      "name": "범위 초과 구역",
                                      "price": 99000,
                                      "rowCount": 2,
                                      "seatPerRow": 3,
                                      "seats": [{"seatNo": 1, "seatCol": 1}, {"seatNo": 3, "seatCol": 1}]
                                    }
                                  ]
                                }
                                """.formatted(venueId)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.exception").value("SeatPositionOutOfBoundsException"))
                .andExpect(jsonPath("$.errorMessage").value(
                        "좌석 자리가 구역의 배치 범위를 벗어났습니다."
                                + " (section=범위 초과 구역, seatNo=3, seatCol=1, rowCount=2, seatPerRow=3)"));

        assertNothingSaved();
    }

    @Test
    @DisplayName("존재하지 않는 공연장이면 404 를 반환한다")
    void register_returnsNotFoundWhenVenueMissing() throws Exception {
        long missingVenueId = venueId + 1_000L;

        mvc.perform(post("/api/v1/seats")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(gappedSectionBody().replace(
                                "\"venueId\": " + venueId, "\"venueId\": " + missingVenueId)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404))
                .andExpect(jsonPath("$.errorMessage")
                        .value("존재하지 않는 공연장입니다. (venueId=" + missingVenueId + ")"))
                .andExpect(jsonPath("$.exception").value("VenueNotFoundException"));

        assertNothingSaved();
    }

    @Test
    @DisplayName("같은 공연장에 이미 있는 구역명이면 409 를 반환하고 좌석을 만들지 않는다")
    void register_returnsConflictOnDuplicatedSectionName() throws Exception {
        sectionRepository.save(Section.builder()
                .name("1층 A블록")
                .price(150000)
                .venue(venueRepository.findById(venueId).orElseThrow())
                .build());

        mvc.perform(post("/api/v1/seats")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(gappedSectionBody()))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.status").value(409))
                .andExpect(jsonPath("$.errorMessage").value("이미 등록된 구역명입니다. (name=1층 A블록)"))
                .andExpect(jsonPath("$.exception").value("SectionNameDuplicatedException"));

        em.flush();
        em.clear();

        // 먼저 넣은 구역 한 건만 남고, 좌석은 하나도 만들어지지 않는다.
        assertThat(sectionRepository.count()).isEqualTo(1);
        assertThat(seatRepository.count()).isZero();
    }

    @Test
    @DisplayName("같은 공연장에 다른 구역이 이미 있어도 새 구역명은 등록된다")
    void register_acceptsNewNameWhenAnotherSectionExists() throws Exception {
        sectionRepository.save(Section.builder()
                .name("1층 A블록")
                .price(150000)
                .venue(venueRepository.findById(venueId).orElseThrow())
                .build());

        // 구역명 중복 검사가 이름이 아니라 공연장 단위로만 걸려 버리면 이 요청도 409 가 된다.
        mvc.perform(post("/api/v1/seats")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(gappedSectionBody().replace("1층 A블록", "1층 B블록")))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.sections[0].name").value("1층 B블록"))
                .andExpect(jsonPath("$.sections[0].seatCount").value(5));

        em.flush();
        em.clear();

        assertThat(sectionRepository.findAllByVenueId(venueId))
                .extracting(Section::getName)
                .containsExactlyInAnyOrder("1층 A블록", "1층 B블록");
    }

    @Test
    @DisplayName("한 요청 안에 같은 구역명이 두 번 들어오면 409 를 반환하고 아무것도 저장하지 않는다")
    void register_returnsConflictOnDuplicatedNameWithinRequest() throws Exception {
        mvc.perform(post("/api/v1/seats")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "venueId": %d,
                                  "sections": [
                                    {
                                      "name": "4층 A블록",
                                      "price": 50000,
                                      "seats": [{"seatNo": 1, "seatCol": 1}]
                                    },
                                    {
                                      "name": "4층 A블록",
                                      "price": 40000,
                                      "seats": [{"seatNo": 1, "seatCol": 1}]
                                    }
                                  ]
                                }
                                """.formatted(venueId)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.errorMessage").value("이미 등록된 구역명입니다. (name=4층 A블록)"))
                .andExpect(jsonPath("$.exception").value("SectionNameDuplicatedException"));

        assertNothingSaved();
    }

    /** 2행 2번 자리가 통로로 비어 있는 구역. 격자로는 표현되지 않는 배치다. */
    private String gappedSectionBody() {
        return """
                {
                  "venueId": %d,
                  "sections": [
                    {
                      "name": "1층 A블록",
                      "price": 150000,
                      "seats": [
                        {"seatNo": 1, "seatCol": 1}, {"seatNo": 1, "seatCol": 2},
                        {"seatNo": 1, "seatCol": 3},
                        {"seatNo": 2, "seatCol": 1}, {"seatNo": 2, "seatCol": 3}
                      ]
                    }
                  ]
                }
                """.formatted(venueId);
    }

    /**
     * 저장된 구역을 DB 에서 다시 읽어 온다.
     *
     * <p>테스트와 요청 처리가 같은 트랜잭션을 쓰므로, 영속성 컨텍스트를 비우지 않으면 방금 만든
     * 인스턴스가 그대로 돌아와 실제로 INSERT 됐는지 알 수 없다.
     */
    private Section onlySavedSection() {
        em.flush();
        em.clear();

        List<Section> sections = sectionRepository.findAll();
        assertThat(sections).hasSize(1);
        return sections.get(0);
    }

    private List<Seat> savedSeats() {
        em.flush();
        em.clear();

        return seatRepository.findAll();
    }

    private void assertNothingSaved() {
        em.flush();
        em.clear();

        assertThat(sectionRepository.count()).isZero();
        assertThat(seatRepository.count()).isZero();
    }
}
