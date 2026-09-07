package com.ssafy.timo.domain.venue;

import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.global.exception.ErrorCode;
import com.ssafy.timo.support.IntegrationTest;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.MockMvc;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 공연장 등록 API 통합 테스트.
 *
 * <p>컨트롤러부터 서비스, JPA, 실제 MySQL 까지 그대로 태운다. 중복 공연장명 409 처럼
 * 기존 행이 있어야 드러나는 동작도 실제 데이터를 넣고 검증한다.
 */
@IntegrationTest
class VenueApiIntegrationTest {

    @Autowired
    private MockMvc mvc;

    @Autowired
    private VenueRepository venueRepository;

    @Autowired
    private EntityManager em;

    @Test
    @DisplayName("공연장을 등록하면 201 과 함께 생성된 리소스 위치를 반환한다")
    void register_returnsCreatedWithLocation() throws Exception {
        MvcResult result = mvc.perform(post("/api/v1/venues")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"고척돔","address":"서울시 구로구 경인로 430","totalSeatCount":16000}
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.name").value("고척돔"))
                .andExpect(jsonPath("$.address").value("서울시 구로구 경인로 430"))
                .andExpect(jsonPath("$.totalSeatCount").value(16000))
                .andReturn();

        Venue saved = onlySavedVenue();

        assertThat(result.getResponse().getHeader("Location"))
                .isEqualTo("/api/v1/venues/" + saved.getId());
        assertThat(saved.getName()).isEqualTo("고척돔");
        assertThat(saved.getAddress()).isEqualTo("서울시 구로구 경인로 430");
        assertThat(saved.getTotalSeatCount()).isEqualTo(16000);
    }

    @Test
    @DisplayName("총 좌석 수가 0 이어도 등록된다")
    void register_acceptsZeroSeatCount() throws Exception {
        mvc.perform(post("/api/v1/venues")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"소극장","address":"서울시 종로구 대학로 12","totalSeatCount":0}
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.totalSeatCount").value(0));

        assertThat(onlySavedVenue().getTotalSeatCount()).isZero();
    }

    @Test
    @DisplayName("공연장명이 공백이면 400 과 필드 에러를 반환하고 아무것도 저장하지 않는다")
    void register_rejectsBlankName() throws Exception {
        mvc.perform(post("/api/v1/venues")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"  ","address":"서울시 구로구 경인로 430","totalSeatCount":16000}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorMessage").value(ErrorCode.INVALID_INPUT_VALUE.getMessage()))
                .andExpect(jsonPath("$.errors[0].field").value("name"))
                .andExpect(jsonPath("$.errors[0].reason").value("공연장명은 필수입니다."));

        assertNothingSaved();
    }

    @Test
    @DisplayName("공연장명이 10자를 넘으면 400 을 반환한다")
    void register_rejectsTooLongName() throws Exception {
        mvc.perform(post("/api/v1/venues")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"올림픽공원 체조경기장","address":"서울시 송파구 올림픽로 424","totalSeatCount":5000}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors[0].field").value("name"))
                .andExpect(jsonPath("$.errors[0].reason").value("공연장명은 10자 이하여야 합니다."));

        assertNothingSaved();
    }

    @Test
    @DisplayName("주소가 비어 있으면 400 을 반환한다")
    void register_rejectsBlankAddress() throws Exception {
        mvc.perform(post("/api/v1/venues")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"고척돔","address":"","totalSeatCount":16000}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors[0].field").value("address"))
                .andExpect(jsonPath("$.errors[0].reason").value("공연장 주소는 필수입니다."));

        assertNothingSaved();
    }

    @Test
    @DisplayName("총 좌석 수가 음수면 400 을 반환한다")
    void register_rejectsNegativeSeatCount() throws Exception {
        mvc.perform(post("/api/v1/venues")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"고척돔","address":"서울시 구로구 경인로 430","totalSeatCount":-1}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors[0].field").value("totalSeatCount"))
                .andExpect(jsonPath("$.errors[0].reason").value("총 좌석 수는 0 이상이어야 합니다."));

        assertNothingSaved();
    }

    @Test
    @DisplayName("이미 등록된 공연장명이면 409 와 도메인 에러 메시지를 반환한다")
    void register_returnsConflictOnDuplicatedName() throws Exception {
        venueRepository.save(Venue.builder()
                .name("고척돔")
                .address("서울시 구로구 경인로 430")
                .totalSeatCount(16000)
                .build());

        mvc.perform(post("/api/v1/venues")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"고척돔","address":"서울시 구로구 경인로 430","totalSeatCount":16000}
                                """))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.status").value(409))
                .andExpect(jsonPath("$.errorMessage").value("이미 등록된 공연장명입니다. (고척돔)"))
                .andExpect(jsonPath("$.exception").value("VenueNameDuplicatedException"));

        // 먼저 넣은 한 건만 남고 중복 저장은 일어나지 않는다.
        em.flush();
        em.clear();
        assertThat(venueRepository.count()).isEqualTo(1);
    }

    /**
     * 저장된 공연장을 DB 에서 다시 읽어 온다.
     *
     * <p>테스트와 요청 처리가 같은 트랜잭션을 쓰므로, 영속성 컨텍스트를 비우지 않으면 방금 만든
     * 인스턴스가 그대로 돌아와 실제로 INSERT 됐는지 알 수 없다.
     */
    private Venue onlySavedVenue() {
        em.flush();
        em.clear();

        var venues = venueRepository.findAll();
        assertThat(venues).hasSize(1);
        return venues.get(0);
    }

    private void assertNothingSaved() {
        em.flush();
        em.clear();

        assertThat(venueRepository.count()).isZero();
    }
}
