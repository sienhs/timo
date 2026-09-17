package com.ssafy.timo.domain.artist;

import com.jayway.jsonpath.JsonPath;
import com.ssafy.timo.domain.artist.entity.Artist;
import com.ssafy.timo.domain.artist.repository.ArtistRepository;
import com.ssafy.timo.global.exception.ErrorCode;
import com.ssafy.timo.support.IntegrationTest;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.MockMvc;

import java.util.ArrayList;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 아티스트 목록 조회 API 통합 테스트.
 *
 * <p>정렬과 필터는 DB 가 실제로 수행하는 부분이라 서비스만 단위 테스트해서는 검증되지 않는다.
 * 특히 {@code nulls last} 는 MySQL 에 해당 문법이 없어 Hibernate 가 {@code case when} 으로
 * 바꿔 주는 동작이라, 운영과 같은 MySQL 을 태워야 확인된다.
 *
 * <p>선행 데이터는 각 테스트가 리포지토리로 직접 넣는다. {@code @IntegrationTest} 가 트랜잭션을
 * 걸어 두므로 테스트가 끝나면 롤백되어 서로 영향을 주지 않는다.
 */
@IntegrationTest
class ArtistListApiIntegrationTest {

    private static final String LIST_PATH = "/api/v1/artists";

    @Autowired
    private MockMvc mvc;

    @Autowired
    private ArtistRepository artistRepository;

    @Autowired
    private EntityManager em;

    @Test
    @DisplayName("조건을 주지 않으면 이름 오름차순 첫 페이지가 기본값으로 내려온다")
    void findAll_returnsFirstPageOrderedByNameByDefault() throws Exception {
        saveArtist("박효신");
        saveArtist("김필");
        saveArtist("아이유");
        flushAndClear();

        mvc.perform(get(LIST_PATH))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(3))
                .andExpect(jsonPath("$.content[0].name").value("김필"))
                .andExpect(jsonPath("$.content[1].name").value("박효신"))
                .andExpect(jsonPath("$.content[2].name").value("아이유"))
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
            saveArtist("아티스트 " + i);
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
            saveArtist("아티스트 " + i);
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
    @DisplayName("NAME 은 이름이 없는 아티스트를 뒤로 보낸다")
    void findAll_sortsByNameWithNullsLast() throws Exception {
        saveArtist("박효신");
        saveArtist(null);
        saveArtist("김필");
        flushAndClear();

        mvc.perform(get(LIST_PATH).param("sort", "NAME"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].name").value("김필"))
                .andExpect(jsonPath("$.content[1].name").value("박효신"))
                .andExpect(jsonPath("$.content[2].name").isEmpty());
    }

    @Test
    @DisplayName("LATEST 는 최근 등록순으로 정렬한다")
    void findAll_sortsByCreatedAtDescendingWhenLatest() throws Exception {
        Long first = saveArtist("먼저 등록").getId();
        Long second = saveArtist("나중 등록").getId();
        flushAndClear();

        mvc.perform(get(LIST_PATH).param("sort", "LATEST"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].id").value(second.intValue()))
                .andExpect(jsonPath("$.content[1].id").value(first.intValue()));
    }

    @Test
    @DisplayName("동명이인이 있어도 페이지를 넘길 때 같은 아티스트가 중복되거나 누락되지 않는다")
    void findAll_keepsStableOrderAcrossPagesOnTiedSortKey() throws Exception {
        // 이름을 모두 같게 두어 정렬 키만으로는 순서가 정해지지 않는 상황을 만든다.
        List<Long> saved = List.of(
                saveArtist("동명이인").getId(),
                saveArtist("동명이인").getId(),
                saveArtist("동명이인").getId());
        flushAndClear();

        List<Integer> firstPage = idsOfPage(0, 2);
        List<Integer> secondPage = idsOfPage(1, 2);

        assertThat(firstPage).hasSize(2);
        assertThat(secondPage).hasSize(1);
        assertThat(firstPage).doesNotContainAnyElementsOf(secondPage);

        List<Integer> all = new ArrayList<>(firstPage);
        all.addAll(secondPage);
        assertThat(all).containsExactlyInAnyOrderElementsOf(
                saved.stream().map(Long::intValue).toList());
    }

    @Test
    @DisplayName("keyword 는 아티스트명 부분 일치로 걸러낸다")
    void findAll_filtersByKeywordOnName() throws Exception {
        saveArtist("아이유");
        saveArtist("아이브");
        saveArtist("박효신");
        flushAndClear();

        mvc.perform(get(LIST_PATH).param("keyword", "아이"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(2))
                .andExpect(jsonPath("$.page.totalElements").value(2));
    }

    @Test
    @DisplayName("keyword 가 공백뿐이면 조건이 없는 것으로 보고 전체를 내려준다")
    void findAll_ignoresBlankKeyword() throws Exception {
        saveArtist("아이유");
        saveArtist("박효신");
        flushAndClear();

        mvc.perform(get(LIST_PATH).param("keyword", "   "))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(2));
    }

    @Test
    @DisplayName("조건에 맞는 아티스트가 없으면 200 과 빈 목록을 내려준다")
    void findAll_returnsEmptyPageWhenNothingMatches() throws Exception {
        saveArtist("아이유");
        flushAndClear();

        mvc.perform(get(LIST_PATH).param("keyword", "존재하지 않는 아티스트"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(0))
                .andExpect(jsonPath("$.page.totalElements").value(0))
                .andExpect(jsonPath("$.page.totalPages").value(0));
    }

    @Test
    @DisplayName("목록 카드에 필요한 필드만 담긴다")
    void findAll_returnsSummaryFields() throws Exception {
        Long artistId = saveArtist("아이유").getId();
        flushAndClear();

        mvc.perform(get(LIST_PATH))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].id").value(artistId.intValue()))
                .andExpect(jsonPath("$.content[0].name").value("아이유"))
                .andExpect(jsonPath("$.content[0].profileImageUrl")
                        .value("https://cdn.test.timo.io/artist/아이유/profile.png"))
                // 출연 공연은 컬렉션이라 목록에 담지 않는다.
                .andExpect(jsonPath("$.content[0].concerts").doesNotExist());
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
        mvc.perform(get(LIST_PATH).param("sort", "name,desc"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.exception").value("MethodArgumentNotValidException"))
                .andExpect(jsonPath("$.errors[0].field").value("sort"));
    }

    private Artist saveArtist(String name) {
        return artistRepository.save(Artist.builder()
                .name(name)
                .profileImageKey("artist/" + name + "/profile.png")
                .build());
    }

    private List<Integer> idsOfPage(int page, int size) throws Exception {
        String body = mvc.perform(get(LIST_PATH)
                        .param("page", String.valueOf(page))
                        .param("size", String.valueOf(size)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        return JsonPath.read(body, "$.content[*].id");
    }

    /**
     * 영속성 컨텍스트를 비워 조회가 1차 캐시가 아니라 DB 를 거치게 한다. 정렬과 필터는 DB 가 하는
     * 일이라 이 과정을 생략하면 검증하려는 동작이 실행되지 않는다.
     */
    private void flushAndClear() {
        em.flush();
        em.clear();
    }
}
