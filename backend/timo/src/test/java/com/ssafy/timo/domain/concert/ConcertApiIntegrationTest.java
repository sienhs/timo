package com.ssafy.timo.domain.concert;

import com.ssafy.timo.domain.artist.entity.Artist;
import com.ssafy.timo.domain.artist.repository.ArtistRepository;
import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.entity.ConcertImage;
import com.ssafy.timo.domain.concert.entity.ConcertStatus;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.global.exception.ErrorCode;
import com.ssafy.timo.support.IntegrationTest;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.containsInAnyOrder;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 공연 생성 API 통합 테스트.
 *
 * <p>컨트롤러부터 서비스, JPA, 실제 MySQL 까지 그대로 태운다. 서비스를 가짜로 바꾸지 않으므로
 * "없는 아티스트면 404", "중복 아티스트는 합쳐진다"처럼 DB 를 거쳐야만 드러나는 동작까지 검증한다.
 *
 * <p>선행 데이터는 매 테스트 시작 시 리포지토리로 직접 넣는다. {@code @IntegrationTest} 가
 * 트랜잭션을 걸어 두므로 테스트가 끝나면 롤백되어 서로 영향을 주지 않는다.
 */
@IntegrationTest
class ConcertApiIntegrationTest {

    private static final String IMAGE_BASE_URL = "https://cdn.test.timo.io";

    @Autowired
    private MockMvc mvc;

    @Autowired
    private ConcertRepository concertRepository;

    @Autowired
    private VenueRepository venueRepository;

    @Autowired
    private ArtistRepository artistRepository;

    @Autowired
    private EntityManager em;

    private Long venueId;
    private Long iuId;
    private Long parkId;

    @BeforeEach
    void setUpFixtures() {
        venueId = venueRepository.save(Venue.builder()
                .name("고척돔")
                .address("서울시 구로구 경인로 430")
                .totalSeatCount(16000)
                .build()).getId();

        iuId = artistRepository.save(Artist.builder()
                .name("아이유")
                .profileImage("artist/1/profile.png")
                .build()).getId();

        parkId = artistRepository.save(Artist.builder()
                .name("박효신")
                .profileImage("artist/2/profile.png")
                .build()).getId();
    }

    @Test
    @DisplayName("공연을 생성하면 201 과 함께 생성된 리소스 위치를 반환한다")
    void create_returnsCreatedWithLocation() throws Exception {
        mvc.perform(post("/api/v1/concerts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(fullBody()))
                .andExpect(status().isCreated())
                .andExpect(header().exists("Location"))
                .andExpect(jsonPath("$.title").value("아이유 콘서트"))
                .andExpect(jsonPath("$.genre").value("CONCERT"))
                .andExpect(jsonPath("$.ageRating").value("AGE_7"))
                .andExpect(jsonPath("$.startDate").value("2026-04-10T19:00:00"))
                .andExpect(jsonPath("$.venueId").value(venueId.intValue()))
                .andExpect(jsonPath("$.venueName").value("고척돔"));
    }

    @Test
    @DisplayName("Location 헤더의 경로는 실제로 저장된 공연의 id 를 가리킨다")
    void create_locationPointsToSavedConcert() throws Exception {
        MvcResult result = mvc.perform(post("/api/v1/concerts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(fullBody()))
                .andExpect(status().isCreated())
                .andReturn();

        Long savedId = onlySavedConcert().getId();

        // 헤더의 경로와 본문의 id 가 어긋나면 클라이언트가 엉뚱한 리소스를 조회한다.
        assertThat(result.getResponse().getHeader("Location"))
                .isEqualTo("/api/v1/concerts/" + savedId);
        assertThat(result.getResponse().getContentAsString())
                .contains("\"id\":" + savedId);
    }

    @Test
    @DisplayName("상태와 조회수는 요청에 없어도 서버가 정한다")
    void create_serverDecidesStatusAndViewCount() throws Exception {
        mvc.perform(post("/api/v1/concerts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(fullBody()))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("SCHEDULED"))
                .andExpect(jsonPath("$.viewCount").value(0));

        Concert saved = onlySavedConcert();
        assertThat(saved.getStatus()).isEqualTo(ConcertStatus.SCHEDULED);
        assertThat(saved.getViewCount()).isZero();
    }

    @Test
    @DisplayName("이미지 key 가 URL 로 변환돼 요청 순서대로 응답에 담긴다")
    void create_convertsImageKeysToUrlsInOrder() throws Exception {
        mvc.perform(post("/api/v1/concerts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(fullBody()))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.posterImageUrl")
                        .value(IMAGE_BASE_URL + "/concert/1/poster.png"))
                .andExpect(jsonPath("$.imageUrls.length()").value(2))
                .andExpect(jsonPath("$.imageUrls[0]")
                        .value(IMAGE_BASE_URL + "/concert/1/detail-1.png"))
                .andExpect(jsonPath("$.imageUrls[1]")
                        .value(IMAGE_BASE_URL + "/concert/1/detail-2.png"));
    }

    @Test
    @DisplayName("이미지는 key 로 저장되고 노출 순서가 함께 기록된다")
    void create_persistsImageKeysWithSortOrder() throws Exception {
        mvc.perform(post("/api/v1/concerts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(fullBody()))
                .andExpect(status().isCreated());

        List<ConcertImage> images = onlySavedConcert().getImages();

        assertThat(images).extracting(ConcertImage::getImageKey)
                .containsExactly("concert/1/detail-1.png", "concert/1/detail-2.png");
        assertThat(images).extracting(ConcertImage::getSortOrder)
                .containsExactly(0, 1);
    }

    @Test
    @DisplayName("출연 아티스트가 요청 순서대로 저장되고 응답에 함께 내려온다")
    void create_persistsArtistsInRequestedOrder() throws Exception {
        mvc.perform(post("/api/v1/concerts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(fullBody()))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.artists.length()").value(2))
                .andExpect(jsonPath("$.artists[0].id").value(iuId.intValue()))
                .andExpect(jsonPath("$.artists[0].name").value("아이유"))
                .andExpect(jsonPath("$.artists[1].name").value("박효신"));

        assertThat(onlySavedConcert().getArtists())
                .extracting(Artist::getName)
                .containsExactly("아이유", "박효신");
    }

    @Test
    @DisplayName("같은 아티스트를 여러 번 넣으면 한 명으로 합쳐진다")
    void create_mergesDuplicatedArtists() throws Exception {
        String body = fullBody().replace(
                "\"artistIds\": [%d, %d]".formatted(iuId, parkId),
                "\"artistIds\": [%d, %d, %d]".formatted(iuId, iuId, iuId));

        mvc.perform(post("/api/v1/concerts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.artists.length()").value(1));

        assertThat(onlySavedConcert().getArtists()).hasSize(1);
    }

    @Test
    @DisplayName("일정과 이미지가 없어도 최소 필드만으로 생성된다")
    void create_acceptsMinimalRequest() throws Exception {
        mvc.perform(post("/api/v1/concerts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "소극장 단독 공연",
                                  "genre": "PLAY",
                                  "ageRating": "ALL",
                                  "venueId": %d,
                                  "artistIds": [%d]
                                }
                                """.formatted(venueId, iuId)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.startDate").isEmpty())
                .andExpect(jsonPath("$.endDate").isEmpty())
                .andExpect(jsonPath("$.openAt").isEmpty())
                .andExpect(jsonPath("$.posterImageUrl").isEmpty())
                .andExpect(jsonPath("$.imageUrls.length()").value(0));

        Concert saved = onlySavedConcert();
        assertThat(saved.getGenre()).isEqualTo(ConcertGenre.PLAY);
        assertThat(saved.getAgeRating()).isEqualTo(AgeRating.ALL);
        assertThat(saved.getStartDate()).isNull();
        assertThat(saved.getPosterImageKey()).isNull();
        assertThat(saved.getImages()).isEmpty();
    }

    @Test
    @DisplayName("필수값이 빠지면 400 과 필드 에러를 반환하고 아무것도 저장하지 않는다")
    void create_rejectsMissingRequiredFields() throws Exception {
        mvc.perform(post("/api/v1/concerts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title":"  ","venueId":null,"artistIds":null}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorMessage").value(ErrorCode.INVALID_INPUT_VALUE.getMessage()))
                .andExpect(jsonPath("$.errors[*].field")
                        .value(containsInAnyOrder("title", "genre", "ageRating", "venueId", "artistIds")));

        assertNothingSaved();
    }

    @Test
    @DisplayName("출연 아티스트가 비어 있으면 400 을 반환한다")
    void create_rejectsEmptyArtistIds() throws Exception {
        String body = fullBody().replace(
                "\"artistIds\": [%d, %d]".formatted(iuId, parkId), "\"artistIds\": []");

        mvc.perform(post("/api/v1/concerts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors[0].field").value("artistIds"))
                .andExpect(jsonPath("$.errors[0].reason").value("출연 아티스트는 최소 1명이어야 합니다."));

        assertNothingSaved();
    }

    @Test
    @DisplayName("공연명이 200자를 넘으면 400 을 반환한다")
    void create_rejectsTooLongTitle() throws Exception {
        mvc.perform(post("/api/v1/concerts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(fullBody().replace("아이유 콘서트", "가".repeat(201))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors[0].field").value("title"))
                .andExpect(jsonPath("$.errors[0].reason").value("공연명은 200자 이하여야 합니다."));

        assertNothingSaved();
    }

    @Test
    @DisplayName("정의되지 않은 장르 값이면 400 과 함께 허용되는 값을 알려준다")
    void create_rejectsUnknownGenre() throws Exception {
        mvc.perform(post("/api/v1/concerts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(fullBody().replace("\"CONCERT\"", "\"OPERA\"")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorMessage").value(ErrorCode.INVALID_INPUT_VALUE.getMessage()))
                .andExpect(jsonPath("$.errors[0].field").value("genre"))
                .andExpect(jsonPath("$.errors[0].reason").value(
                        "허용되지 않는 값입니다: OPERA (가능한 값: CONCERT, MUSICAL, PLAY, CLASSIC, FESTIVAL, SPORTS)"));

        assertNothingSaved();
    }

    @Test
    @DisplayName("존재하지 않는 공연장이면 404 를 반환한다")
    void create_returnsNotFoundWhenVenueMissing() throws Exception {
        long missingVenueId = venueId + 1_000L;

        mvc.perform(post("/api/v1/concerts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(fullBody().replace("\"venueId\": " + venueId,
                                "\"venueId\": " + missingVenueId)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404))
                .andExpect(jsonPath("$.errorMessage")
                        .value("존재하지 않는 공연장입니다. (venueId=" + missingVenueId + ")"))
                .andExpect(jsonPath("$.exception").value("VenueNotFoundException"));

        assertNothingSaved();
    }

    @Test
    @DisplayName("존재하지 않는 아티스트가 섞여 있으면 404 를 반환한다")
    void create_returnsNotFoundWhenArtistMissing() throws Exception {
        long missingArtistId = parkId + 1_000L;
        String body = fullBody().replace(
                "\"artistIds\": [%d, %d]".formatted(iuId, parkId),
                "\"artistIds\": [%d, %d]".formatted(iuId, missingArtistId));

        mvc.perform(post("/api/v1/concerts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorMessage")
                        .value("존재하지 않는 아티스트입니다. (artistId=" + missingArtistId + ")"))
                .andExpect(jsonPath("$.exception").value("ArtistNotFoundException"));

        assertNothingSaved();
    }

    @Test
    @DisplayName("공연 기간이 뒤집혀 있으면 400 과 도메인 에러 메시지를 반환한다")
    void create_returnsBadRequestOnReversedPeriod() throws Exception {
        mvc.perform(post("/api/v1/concerts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(fullBody()
                                .replace("\"endDate\": \"2026-04-12T21:00:00\"",
                                        "\"endDate\": \"2026-04-09T21:00:00\"")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorMessage").value("공연 종료일은 시작일보다 빠를 수 없습니다."))
                .andExpect(jsonPath("$.exception").value("InvalidConcertPeriodException"));

        assertNothingSaved();
    }

    @Test
    @DisplayName("예매 오픈이 공연 시작보다 늦으면 400 을 반환한다")
    void create_returnsBadRequestWhenOpenAtIsAfterStart() throws Exception {
        mvc.perform(post("/api/v1/concerts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(fullBody()
                                .replace("\"openAt\": \"2026-03-01T20:00:00\"",
                                        "\"openAt\": \"2026-04-11T20:00:00\"")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorMessage").value("예매 오픈은 공연 시작 전이어야 합니다."))
                .andExpect(jsonPath("$.exception").value("InvalidTicketOpenTimeException"));

        assertNothingSaved();
    }

    @Test
    @DisplayName("공연을 조회하면 공연장·아티스트·이미지까지 담긴 상세가 반환된다")
    void find_returnsConcertDetail() throws Exception {
        Long concertId = saveFullConcert().getId();

        mvc.perform(get("/api/v1/concerts/{concertId}", concertId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(concertId.intValue()))
                .andExpect(jsonPath("$.title").value("아이유 콘서트"))
                .andExpect(jsonPath("$.venueId").value(venueId.intValue()))
                .andExpect(jsonPath("$.venueName").value("고척돔"))
                .andExpect(jsonPath("$.artists.length()").value(2))
                .andExpect(jsonPath("$.artists[0].name").value("아이유"))
                .andExpect(jsonPath("$.artists[1].name").value("박효신"))
                .andExpect(jsonPath("$.imageUrls.length()").value(2));
    }

    @Test
    @DisplayName("조회할 때마다 조회수가 1씩 증가한다")
    void find_increasesViewCountOnEachCall() throws Exception {
        Long concertId = saveFullConcert().getId();
        em.flush();
        em.clear();

        mvc.perform(get("/api/v1/concerts/{concertId}", concertId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.viewCount").value(1));

        // 벌크 업데이트는 영속성 컨텍스트를 갱신하지 않으므로, 직전 조회로 캐시된 엔티티를
        // 비워야 두 번째 조회가 DB 에 반영된 최신 조회수를 읽는다.
        em.clear();

        mvc.perform(get("/api/v1/concerts/{concertId}", concertId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.viewCount").value(2));

        em.clear();
        assertThat(concertRepository.findById(concertId).orElseThrow().getViewCount()).isEqualTo(2);
    }

    @Test
    @DisplayName("취소·종료된 공연도 상세는 그대로 조회된다")
    void find_returnsConcertRegardlessOfStatus() throws Exception {
        Concert concert = saveFullConcert();
        ReflectionTestUtils.setField(concert, "status", ConcertStatus.CANCELED);
        concertRepository.save(concert);
        em.flush();
        em.clear();

        mvc.perform(get("/api/v1/concerts/{concertId}", concert.getId()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CANCELED"));
    }

    @Test
    @DisplayName("존재하지 않는 공연을 조회하면 404 를 반환한다")
    void find_returnsNotFoundWhenMissing() throws Exception {
        long missingConcertId = 999_999L;

        mvc.perform(get("/api/v1/concerts/{concertId}", missingConcertId))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorMessage")
                        .value("존재하지 않는 공연입니다. (concertId=" + missingConcertId + ")"))
                .andExpect(jsonPath("$.exception").value("ConcertNotFoundException"));
    }

    private Concert saveFullConcert() {
        Concert concert = Concert.builder()
                .title("아이유 콘서트")
                .genre(ConcertGenre.CONCERT)
                .posterImageKey("concert/1/poster.png")
                .description("2026 아이유 단독 콘서트")
                .ageRating(AgeRating.AGE_7)
                .startDate(LocalDateTime.of(2026, 4, 10, 19, 0))
                .endDate(LocalDateTime.of(2026, 4, 12, 21, 0))
                .openAt(LocalDateTime.of(2026, 3, 1, 20, 0))
                .venue(venueRepository.getReferenceById(venueId))
                .build();

        concert.addArtist(artistRepository.getReferenceById(iuId));
        concert.addArtist(artistRepository.getReferenceById(parkId));
        concert.addImage("concert/1/detail-1.png");
        concert.addImage("concert/1/detail-2.png");

        return concertRepository.save(concert);
    }

    private String fullBody() {
        return """
                {
                  "title": "아이유 콘서트",
                  "genre": "CONCERT",
                  "posterImageKey": "concert/1/poster.png",
                  "imageKeys": ["concert/1/detail-1.png", "concert/1/detail-2.png"],
                  "description": "2026 아이유 단독 콘서트",
                  "ageRating": "AGE_7",
                  "startDate": "2026-04-10T19:00:00",
                  "endDate": "2026-04-12T21:00:00",
                  "openAt": "2026-03-01T20:00:00",
                  "venueId": %d,
                  "artistIds": [%d, %d]
                }
                """.formatted(venueId, iuId, parkId);
    }

    /**
     * 저장된 공연을 DB 에서 다시 읽어 온다.
     *
     * <p>테스트와 요청 처리가 같은 트랜잭션을 쓰므로, 영속성 컨텍스트를 비우지 않으면 방금 만든
     * 인스턴스가 그대로 돌아와 실제로 INSERT 됐는지 알 수 없다.
     */
    private Concert onlySavedConcert() {
        em.flush();
        em.clear();

        List<Concert> concerts = concertRepository.findAll();
        assertThat(concerts).hasSize(1);
        return concerts.get(0);
    }

    private void assertNothingSaved() {
        em.flush();
        em.clear();

        assertThat(concertRepository.count()).isZero();
    }
}
