package com.ssafy.timo.domain.transfer.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

/**
 * 마켓 목록 조회의 공통 요청. 모든 조건은 선택값이다.
 *
 * <p>마켓의 목록 API 세 개(양도마켓 공연 목록 · 콘서트별 매물 · 내 거래 내역)가 받는 조건이
 * 페이지 번호와 크기뿐이라 하나로 묶었다. 공연 식별자는 쿼리가 아니라 경로에서 온다.
 *
 * <p><b>정렬 조건을 받지 않는다.</b> 세 API 모두 의미 있는 순서가 하나뿐이기 때문이다 —
 * 매물은 낮은 가격순, 공연 목록은 임박순, 내 내역은 최신순. 대신 정렬이 API마다 다르므로
 * {@link #toPageable(Sort)} 로 호출하는 쪽이 넘긴다. 필드명을 열어 두면 매핑되지 않는 속성일 때
 * 500 이 나고, 매핑되면 내부 모델 구조가 그대로 API 규약이 된다.
 */
public record MarketListRequestDto(

        @Min(value = 0, message = "페이지 번호는 0 이상이어야 합니다.")
        Integer page,

        @Min(value = 1, message = "페이지 크기는 1 이상이어야 합니다.")
        @Max(value = MAX_SIZE, message = "페이지 크기는 " + MAX_SIZE + " 이하여야 합니다.")
        Integer size
) {
    private static final int MAX_SIZE = 100;
    private static final int DEFAULT_PAGE = 0;
    private static final int DEFAULT_SIZE = 20;

    /**
     * 호출하는 쪽이 정한 정렬로 페이지 조건을 만든다.
     *
     * <p>상한이 없으면 한 번의 요청으로 테이블 전체를 끌어갈 수 있어 {@code size} 를 100 으로 막는다.
     */
    public Pageable toPageable(Sort sort) {
        return PageRequest.of(
                page == null ? DEFAULT_PAGE : page,
                size == null ? DEFAULT_SIZE : size,
                sort);
    }
}
