package com.ssafy.timo.domain.concert.dto;

import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.entity.ConcertStatus;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

/**
 * 공연 목록 조회 조건. 모두 선택값이고, 아무것도 넘기지 않으면 최근 등록순 첫 페이지가 나온다.
 *
 * <p>{@code Pageable} 을 컨트롤러 파라미터로 직접 받지 않는다. Spring Data 의 리졸버는
 * {@code sort} 를 "필드명,방향" 으로 해석하는데, 이 API 는 같은 이름을
 * {@link ConcertSortType} 으로 받기 때문에 규약이 겹친다. 페이지 정보도 여기서 함께 받아
 * 쿼리 파라미터의 의미를 한곳에서 정한다.
 */
public record ConcertListRequestDto(

        @Min(value = 0, message = "페이지 번호는 0 이상이어야 합니다.")
        Integer page,

        @Min(value = 1, message = "페이지 크기는 1 이상이어야 합니다.")
        @Max(value = MAX_SIZE, message = "페이지 크기는 " + MAX_SIZE + " 이하여야 합니다.")
        Integer size,

        ConcertSortType sort,

        ConcertGenre genre,

        ConcertStatus status,

        /** 공연명 부분 일치. 공백만 넘기면 조건이 없는 것으로 본다. */
        @Size(max = 200, message = "검색어는 200자 이하여야 합니다.")
        String keyword
) {

    /** 한 번에 내려줄 수 있는 최대 개수. 이보다 크게 요청하면 400 이다. */
    private static final int MAX_SIZE = 100;

    private static final int DEFAULT_PAGE = 0;
    private static final int DEFAULT_SIZE = 20;
    private static final ConcertSortType DEFAULT_SORT = ConcertSortType.LATEST;

    public Pageable toPageable() {
        return PageRequest.of(
                page == null ? DEFAULT_PAGE : page,
                size == null ? DEFAULT_SIZE : size,
                (sort == null ? DEFAULT_SORT : sort).toSort());
    }

    /**
     * 검색어를 조건으로 쓸 수 있는 형태로 돌려준다.
     *
     * <p>{@code ?keyword=} 처럼 빈 값이 오면 {@code null} 로 바꾼다. 그대로 두면
     * {@code like '%%'} 가 되어 인덱스를 타지 못하는 전체 스캔이 되고, "검색어 없음"과
     * 결과가 같으면서 쿼리만 무거워진다.
     */
    public String keywordOrNull() {
        return keyword == null || keyword.isBlank() ? null : keyword.trim();
    }
}
