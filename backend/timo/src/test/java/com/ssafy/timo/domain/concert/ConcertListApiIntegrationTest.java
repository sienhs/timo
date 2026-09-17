package com.ssafy.timo.domain.concert;

import com.jayway.jsonpath.JsonPath;
import com.ssafy.timo.domain.artist.entity.Artist;
import com.ssafy.timo.domain.artist.repository.ArtistRepository;
import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
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
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 공연 목록 조회 API 통합 테스트.
 *
 * <p>정렬과 필터는 DB 가 실제로 수행하는 부분이라 서비스만 단위 테스트해서는 검증되지 않는다.
 * {@code nulls last} 처리나 enum 파라미터가 {@code null} 인 조건절처럼 방언에 따라 달라지는
 * 동작이 있어, 운영과 같은 MySQL 을 태운다.
 *
 * <p>선행 데이터는 매 테스트 시작 시 리포지토리로 직접 넣는다. {@code @IntegrationTest} 가
 * 트랜잭션을 걸어 두므로 테스트가 끝나면 롤백되어 서로 영향을 주지 않는다.
 */
@IntegrationTest
class ConcertListApiIntegrationTest {

    private static final String LIST_PATH = "/api/v1/concerts";
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
    private Long artistId;

    @BeforeEach
    void setUpFixtures() {
        venueId = venueRepository.save(Venue.builder()
                .name("고척돔")
                .address("서울시 구로구 경인로 430")
                .totalSeatCount(16000)
                .build()).getId();

        artistId = artistRepository.save(Artist.builder()
                .name("아이유")
                .profileImageKey("artist/1/profile.png")
                .build()).getId();
    }

    @Test
    @DisplayName("조건을 주지 않으면 최근 등록순 첫 페이지가 기본값으로 내려온다")
    void findAll_returnsFirstPageOrderedByLatestByDefault() throws Exception {
        Long first = saveConcert("첫 번째 공연").getId();
        Long second = saveConcert("두 번째 공연").getId();
        Long third = saveConcert("세 번째 공연").getId();
        flushAndClear();

        mvc.perform(get(LIST_PATH))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(3))
                .andExpect(jsonPath("$.content[0].id").value(third.intValue()))
                .andExpect(jsonPath("$.content[1].id").value(second.intValue()))
                .andExpect(jsonPath("$.content[2].id").value(first.intValue()))
                .andExpect(jsonPath("$.page.number").value(0))
                .andExpect(jsonPath("$.page.size").value(20))
                .andExpect(jsonPath("$.page.totalElements").value(3))
                .andExpect(jsonPath("$.page.totalPages").value(1))
                // PagedModel 은 first/last 를 담지 않는다. 클라이언트는 number 와 totalPages 로 판단한다.
                .andExpect(jsonPath("$.first").doesNotExist())
                .andExpect(jsonPath("$.last").doesNotExist())
                // Page 를 그대로 직렬화할 때 새어 나오던 내부 필드도 없어야 한다.
                .andExpect(jsonPath("$.pageable").doesNotExist())
                .andExpect(jsonPath("$.sort").doesNotExist());
    }

    @Test
    @DisplayName("페이지 번호와 크기가 적용되고 전체 개수는 페이지와 무관하게 센다")
    void findAll_appliesPageAndSize() throws Exception {
        for (int i = 1; i <= 5; i++) {
            saveConcert("공연 " + i);
        }
        flushAndClear();

        mvc.perform(get(LIST_PATH).param("page", "1").param("size", "2"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(2))
                .andExpect(jsonPath("$.page.number").value(1))
                .andExpect(jsonPath("$.page.size").value(2))
                .andExpect(jsonPath("$.page.totalElements").value(5))
                .andExpect(jsonPath("$.page.totalPages").value(3));
    }

    @Test
    @DisplayName("마지막 페이지는 남은 개수만 담는다")
    void findAll_returnsRemainderOnLastPage() throws Exception {
        for (int i = 1; i <= 5; i++) {
            saveConcert("공연 " + i);
        }
        flushAndClear();

        mvc.perform(get(LIST_PATH).param("page", "2").param("size", "2"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(1))
                // 마지막 페이지인지는 number 가 totalPages - 1 인지로 판단한다.
                .andExpect(jsonPath("$.page.number").value(2))
                .andExpect(jsonPath("$.page.totalPages").value(3));
    }

    @Test
    @DisplayName("POPULAR 는 조회수 많은 순으로 정렬한다")
    void findAll_sortsByViewCountWhenPopular() throws Exception {
        saveConcertWithViewCount("조회수 5", 5);
        saveConcertWithViewCount("조회수 100", 100);
        saveConcertWithViewCount("조회수 30", 30);
        flushAndClear();

        mvc.perform(get(LIST_PATH).param("sort", "POPULAR"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].title").value("조회수 100"))
                .andExpect(jsonPath("$.content[1].title").value("조회수 30"))
                .andExpect(jsonPath("$.content[2].title").value("조회수 5"));
    }

    @Test
    @DisplayName("OPEN_SOON 은 예매 오픈이 이른 순으로 정렬하고, 오픈 미정인 공연은 뒤로 보낸다")
    void findAll_sortsByOpenAtWithNullsLastWhenOpenSoon() throws Exception {
        saveConcertWithOpenAt("3월 오픈", LocalDateTime.of(2026, 3, 1, 20, 0));
        saveConcertWithOpenAt("오픈 미정", null);
        saveConcertWithOpenAt("1월 오픈", LocalDateTime.of(2026, 1, 15, 20, 0));
        flushAndClear();

        mvc.perform(get(LIST_PATH).param("sort", "OPEN_SOON"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].title").value("1월 오픈"))
                .andExpect(jsonPath("$.content[1].title").value("3월 오픈"))
                .andExpect(jsonPath("$.content[2].title").value("오픈 미정"))
                .andExpect(jsonPath("$.content[2].openAt").isEmpty());
    }

    @Test
    @DisplayName("START_DATE 는 공연 시작이 이른 순으로 정렬하고, 일정 미정인 공연은 뒤로 보낸다")
    void findAll_sortsByStartDateWithNullsLast() throws Exception {
        saveConcertWithStartDate("5월 공연", LocalDateTime.of(2026, 5, 1, 19, 0));
        saveConcertWithStartDate("일정 미정", null);
        saveConcertWithStartDate("2월 공연", LocalDateTime.of(2026, 2, 1, 19, 0));
        flushAndClear();

        mvc.perform(get(LIST_PATH).param("sort", "START_DATE"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].title").value("2월 공연"))
                .andExpect(jsonPath("$.content[1].title").value("5월 공연"))
                .andExpect(jsonPath("$.content[2].title").value("일정 미정"));
    }

    @Test
    @DisplayName("정렬 키가 같아도 페이지를 넘길 때 같은 공연이 중복되거나 누락되지 않는다")
    void findAll_keepsStableOrderAcrossPagesOnTiedSortKey() throws Exception {
        // 조회수를 모두 같게 두어 정렬 키만으로는 순서가 정해지지 않는 상황을 만든다.
        saveConcertWithViewCount("동점 A", 7);
        saveConcertWithViewCount("동점 B", 7);
        saveConcertWithViewCount("동점 C", 7);
        flushAndClear();

        List<String> firstPage = titlesOfPage(0, 2);
        List<String> secondPage = titlesOfPage(1, 2);

        assertThat(firstPage).hasSize(2);
        assertThat(secondPage).hasSize(1);
        assertThat(firstPage).doesNotContainAnyElementsOf(secondPage);

        List<String> all = new java.util.ArrayList<>(firstPage);
        all.addAll(secondPage);
        assertThat(all).containsExactlyInAnyOrder("동점 A", "동점 B", "동점 C");
    }

    @Test
    @DisplayName("genre 를 주면 해당 장르만 내려온다")
    void findAll_filtersByGenre() throws Exception {
        saveConcertWithGenre("콘서트", ConcertGenre.CONCERT);
        saveConcertWithGenre("뮤지컬", ConcertGenre.MUSICAL);
        saveConcertWithGenre("연극", ConcertGenre.PLAY);
        flushAndClear();

        mvc.perform(get(LIST_PATH).param("genre", "MUSICAL"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(1))
                .andExpect(jsonPath("$.page.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].title").value("뮤지컬"))
                .andExpect(jsonPath("$.content[0].genre").value("MUSICAL"));
    }

    @Test
    @DisplayName("status 를 주면 해당 예매 상태만 내려온다")
    void findAll_filtersByStatus() throws Exception {
        saveConcert("예매 전");
        saveConcertWithStatus("예매 중", ConcertStatus.ON_SALE);
        saveConcertWithStatus("취소됨", ConcertStatus.CANCELED);
        flushAndClear();

        mvc.perform(get(LIST_PATH).param("status", "ON_SALE"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(1))
                .andExpect(jsonPath("$.content[0].title").value("예매 중"))
                .andExpect(jsonPath("$.content[0].status").value("ON_SALE"));
    }

    @Test
    @DisplayName("keyword 는 공연명 부분 일치로 걸러낸다")
    void findAll_filtersByKeywordOnTitle() throws Exception {
        saveConcert("아이유 콘서트");
        saveConcert("아이유 팬미팅");
        saveConcert("박효신 콘서트");
        flushAndClear();

        mvc.perform(get(LIST_PATH).param("keyword", "아이유"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(2))
                .andExpect(jsonPath("$.page.totalElements").value(2));
    }

    @Test
    @DisplayName("keyword 가 공백뿐이면 조건이 없는 것으로 보고 전체를 내려준다")
    void findAll_ignoresBlankKeyword() throws Exception {
        saveConcert("아이유 콘서트");
        saveConcert("박효신 콘서트");
        flushAndClear();

        mvc.perform(get(LIST_PATH).param("keyword", "   "))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(2));
    }

    @Test
    @DisplayName("여러 조건을 함께 주면 모두 만족하는 공연만 내려온다")
    void findAll_combinesFilters() throws Exception {
        saveConcertWithGenreAndStatus("아이유 콘서트", ConcertGenre.CONCERT, ConcertStatus.ON_SALE);
        saveConcertWithGenreAndStatus("아이유 뮤지컬", ConcertGenre.MUSICAL, ConcertStatus.ON_SALE);
        saveConcertWithGenreAndStatus("박효신 콘서트", ConcertGenre.CONCERT, ConcertStatus.ON_SALE);
        saveConcertWithGenreAndStatus("아이유 콘서트 취소분", ConcertGenre.CONCERT, ConcertStatus.CANCELED);
        flushAndClear();

        mvc.perform(get(LIST_PATH)
                        .param("keyword", "아이유")
                        .param("genre", "CONCERT")
                        .param("status", "ON_SALE"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(1))
                .andExpect(jsonPath("$.content[0].title").value("아이유 콘서트"));
    }

    @Test
    @DisplayName("조건에 맞는 공연이 없으면 200 과 빈 목록을 내려준다")
    void findAll_returnsEmptyPageWhenNothingMatches() throws Exception {
        saveConcert("아이유 콘서트");
        flushAndClear();

        mvc.perform(get(LIST_PATH).param("keyword", "존재하지 않는 공연명"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(0))
                .andExpect(jsonPath("$.page.totalElements").value(0))
                .andExpect(jsonPath("$.page.totalPages").value(0));
    }

    @Test
    @DisplayName("목록 카드에 필요한 필드가 담기고, 공연장 이름도 함께 내려온다")
    void findAll_returnsSummaryFieldsWithVenueName() throws Exception {
        saveConcert("아이유 콘서트");
        flushAndClear();

        mvc.perform(get(LIST_PATH))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].title").value("아이유 콘서트"))
                .andExpect(jsonPath("$.content[0].genre").value("CONCERT"))
                .andExpect(jsonPath("$.content[0].ageRating").value("AGE_7"))
                .andExpect(jsonPath("$.content[0].status").value("SCHEDULED"))
                .andExpect(jsonPath("$.content[0].viewCount").value(0))
                .andExpect(jsonPath("$.content[0].startDate").value("2026-04-10T19:00:00"))
                .andExpect(jsonPath("$.content[0].venueId").value(venueId.intValue()))
                .andExpect(jsonPath("$.content[0].venueName").value("고척돔"))
                .andExpect(jsonPath("$.content[0].posterImageUrl")
                        .value(IMAGE_BASE_URL + "/concert/1/poster.png"));
    }

    @Test
    @DisplayName("목록 응답에는 출연 아티스트와 상세 이미지를 담지 않는다")
    void findAll_omitsArtistsAndDetailImages() throws Exception {
        Concert concert = saveConcert("아이유 콘서트");
        concert.addArtist(artistRepository.getReferenceById(artistId));
        concert.addImage("concert/1/detail-1.png");
        concertRepository.save(concert);
        flushAndClear();

        mvc.perform(get(LIST_PATH))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].artists").doesNotExist())
                .andExpect(jsonPath("$.content[0].imageUrls").doesNotExist());
    }

    @Test
    @DisplayName("포스터가 없는 공연은 posterImageUrl 이 비어 있다")
    void findAll_returnsNullPosterUrlWhenPosterMissing() throws Exception {
        concertRepository.save(baseBuilder("포스터 없는 공연").posterImageKey(null).build());
        flushAndClear();

        mvc.perform(get(LIST_PATH))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].posterImageUrl").isEmpty());
    }

    @Test
    @DisplayName("목록을 조회해도 조회수는 올라가지 않는다")
    void findAll_doesNotIncreaseViewCount() throws Exception {
        Long concertId = saveConcert("아이유 콘서트").getId();
        flushAndClear();

        mvc.perform(get(LIST_PATH)).andExpect(status().isOk());
        mvc.perform(get(LIST_PATH)).andExpect(status().isOk());
        flushAndClear();

        assertThat(concertRepository.findById(concertId).orElseThrow().getViewCount()).isZero();
    }

    @Test
    @DisplayName("페이지 번호가 음수면 400 을 반환한다")
    void findAll_rejectsNegativePage() throws Exception {
        mvc.perform(get(LIST_PATH).param("page", "-1"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorMessage").value(ErrorCode.INVALID_INPUT_VALUE.getMessage()))
                .andExpect(jsonPath("$.errors[0].field").value("page"))
                .andExpect(jsonPath("$.errors[0].reason").value("페이지 번호는 0 이상이어야 합니다."));
    }

    @Test
    @DisplayName("페이지 크기가 상한을 넘으면 400 을 반환한다")
    void findAll_rejectsTooLargeSize() throws Exception {
        mvc.perform(get(LIST_PATH).param("size", "101"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors[0].field").value("size"))
                .andExpect(jsonPath("$.errors[0].reason").value("페이지 크기는 100 이하여야 합니다."));
    }

    @Test
    @DisplayName("페이지 크기가 0 이면 400 을 반환한다")
    void findAll_rejectsZeroSize() throws Exception {
        mvc.perform(get(LIST_PATH).param("size", "0"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors[0].field").value("size"))
                .andExpect(jsonPath("$.errors[0].reason").value("페이지 크기는 1 이상이어야 합니다."));
    }

    @Test
    @DisplayName("정의되지 않은 정렬 기준이면 400 을 반환한다")
    void findAll_rejectsUnknownSortType() throws Exception {
        mvc.perform(get(LIST_PATH).param("sort", "viewCount,desc"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.exception").value("MethodArgumentNotValidException"))
                .andExpect(jsonPath("$.errors[0].field").value("sort"));
    }

    @Test
    @DisplayName("정의되지 않은 장르 값이면 400 을 반환한다")
    void findAll_rejectsUnknownGenre() throws Exception {
        mvc.perform(get(LIST_PATH).param("genre", "OPERA"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.exception").value("MethodArgumentNotValidException"))
                .andExpect(jsonPath("$.errors[0].field").value("genre"));
    }

    private Concert saveConcert(String title) {
        return concertRepository.save(baseBuilder(title).build());
    }

    private void saveConcertWithViewCount(String title, int viewCount) {
        Concert concert = baseBuilder(title).build();
        // 조회수는 서버가 정하는 값이라 빌더로 넣을 수 없다. 정렬을 검증하려면 값이 달라야 한다.
        ReflectionTestUtils.setField(concert, "viewCount", viewCount);
        concertRepository.save(concert);
    }

    private void saveConcertWithStatus(String title, ConcertStatus status) {
        Concert concert = baseBuilder(title).build();
        // 상태 전이 API 가 아직 없어 직접 바꾼다.
        ReflectionTestUtils.setField(concert, "status", status);
        concertRepository.save(concert);
    }

    private void saveConcertWithGenre(String title, ConcertGenre genre) {
        concertRepository.save(baseBuilder(title).genre(genre).build());
    }

    private void saveConcertWithGenreAndStatus(String title, ConcertGenre genre, ConcertStatus status) {
        Concert concert = baseBuilder(title).genre(genre).build();
        ReflectionTestUtils.setField(concert, "status", status);
        concertRepository.save(concert);
    }

    private void saveConcertWithOpenAt(String title, LocalDateTime openAt) {
        concertRepository.save(baseBuilder(title).openAt(openAt).build());
    }

    private void saveConcertWithStartDate(String title, LocalDateTime startDate) {
        // 예매 오픈은 공연 시작 전이어야 하므로, 시작일을 바꾸면 오픈 일시도 함께 비운다.
        concertRepository.save(baseBuilder(title).startDate(startDate).openAt(null).build());
    }

    private Concert.ConcertBuilder baseBuilder(String title) {
        return Concert.builder()
                .title(title)
                .genre(ConcertGenre.CONCERT)
                .posterImageKey("concert/1/poster.png")
                .description("설명")
                .ageRating(AgeRating.AGE_7)
                .startDate(LocalDateTime.of(2026, 4, 10, 19, 0))
                .endDate(LocalDateTime.of(2026, 4, 12, 21, 0))
                .openAt(LocalDateTime.of(2026, 3, 1, 20, 0))
                .venue(venueRepository.getReferenceById(venueId));
    }

    /** 한 페이지를 POPULAR 정렬로 조회해 공연명만 뽑아낸다. */
    private List<String> titlesOfPage(int page, int size) throws Exception {
        String body = mvc.perform(get(LIST_PATH)
                        .param("sort", "POPULAR")
                        .param("page", String.valueOf(page))
                        .param("size", String.valueOf(size)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();

        return JsonPath.read(body, "$.content[*].title");
    }

    /**
     * 방금 저장한 내용을 DB 까지 밀어 넣고 영속성 컨텍스트를 비운다.
     *
     * <p>테스트와 요청 처리가 같은 트랜잭션을 쓰므로, 비우지 않으면 조회 결과가 캐시된
     * 인스턴스로 채워져 실제 쿼리의 정렬·필터가 검증되지 않는다.
     */
    private void flushAndClear() {
        em.flush();
        em.clear();
    }
}
