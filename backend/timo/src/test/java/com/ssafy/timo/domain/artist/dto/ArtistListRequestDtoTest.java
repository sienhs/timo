package com.ssafy.timo.domain.artist.dto;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * 목록 조회 조건의 기본값과 정렬 변환 규칙 단위 테스트.
 *
 * <p>스프링 없이 값만 검증한다. 이 규칙들은 DB 를 태우지 않아도 확인할 수 있고,
 * 통합 테스트에서 보면 어떤 값이 어디서 정해졌는지 드러나지 않는다.
 */
class ArtistListRequestDtoTest {

    @Test
    @DisplayName("아무 조건도 주지 않으면 이름순 0 페이지 20건이 된다")
    void toPageable_appliesDefaults() {
        Pageable pageable = new ArtistListRequestDto(null, null, null, null).toPageable();

        assertThat(pageable.getPageNumber()).isZero();
        assertThat(pageable.getPageSize()).isEqualTo(20);
        assertThat(pageable.getSort()).isEqualTo(ArtistSortType.NAME.toSort());
    }

    @Test
    @DisplayName("넘긴 페이지 번호와 크기가 그대로 반영된다")
    void toPageable_usesGivenPageAndSize() {
        Pageable pageable = new ArtistListRequestDto(3, 50, null, null).toPageable();

        assertThat(pageable.getPageNumber()).isEqualTo(3);
        assertThat(pageable.getPageSize()).isEqualTo(50);
    }

    @Test
    @DisplayName("어떤 정렬 기준을 골라도 마지막에는 id 내림차순이 붙는다")
    void toSort_alwaysEndsWithIdDescending() {
        for (ArtistSortType sortType : ArtistSortType.values()) {
            Sort.Order last = sortType.toSort().stream().reduce((first, second) -> second).orElseThrow();

            assertThat(last.getProperty()).as("%s 의 마지막 정렬 키", sortType).isEqualTo("id");
            assertThat(last.getDirection()).as("%s 의 마지막 정렬 방향", sortType).isEqualTo(Sort.Direction.DESC);
        }
    }

    @Test
    @DisplayName("NAME 은 이름 오름차순이고 이름이 없는 행을 뒤로 보낸다")
    void toSort_namePutsNullsLast() {
        Sort.Order first = ArtistSortType.NAME.toSort().iterator().next();

        assertThat(first.getProperty()).isEqualTo("name");
        assertThat(first.getDirection()).isEqualTo(Sort.Direction.ASC);
        assertThat(first.getNullHandling()).isEqualTo(Sort.NullHandling.NULLS_LAST);
    }

    @Test
    @DisplayName("LATEST 는 등록 시각 내림차순이다")
    void toSort_latestOrdersByCreatedAtDescending() {
        Sort.Order first = ArtistSortType.LATEST.toSort().iterator().next();

        assertThat(first.getProperty()).isEqualTo("createdAt");
        assertThat(first.getDirection()).isEqualTo(Sort.Direction.DESC);
    }

    @Test
    @DisplayName("검색어가 없거나 공백뿐이면 조건으로 쓰지 않는다")
    void keywordOrNull_treatsBlankAsAbsent() {
        assertThat(keywordOf(null)).isNull();
        assertThat(keywordOf("")).isNull();
        assertThat(keywordOf("   ")).isNull();
    }

    @Test
    @DisplayName("검색어 앞뒤 공백은 잘라 낸다")
    void keywordOrNull_trimsSurroundingWhitespace() {
        assertThat(keywordOf("  아이유  ")).isEqualTo("아이유");
    }

    private String keywordOf(String keyword) {
        return new ArtistListRequestDto(null, null, null, keyword).keywordOrNull();
    }
}
