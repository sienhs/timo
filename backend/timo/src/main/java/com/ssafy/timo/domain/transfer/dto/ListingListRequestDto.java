package com.ssafy.timo.domain.transfer.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

/**
 * 양도 매물 조회 조건. 모든 조건은 선택값이다.
 *
 * <p>정렬은 낮은 가격순 하나뿐이라 enum 을 두지 않았다. 매물은 정가 이하로만 등록되므로 구매자에게
 * 의미 있는 순서가 그것이다. 동가는 마지막에 유일 키(tokenId 내림차순)를 덧붙여 페이지를 넘길 때
 * 같은 매물이 두 번 나오지 않게 한다.
 */
public record ListingListRequestDto(

        @Min(value = 0, message = "페이지 번호는 0 이상이어야 합니다.")
        Integer page,

        @Min(value = 1, message = "페이지 크기는 1 이상이어야 합니다.")
        @Max(value = MAX_SIZE, message = "페이지 크기는 " + MAX_SIZE + " 이하여야 합니다.")
        Integer size,

        Long concertId
) {
    private static final int MAX_SIZE = 100;
    private static final int DEFAULT_PAGE = 0;
    private static final int DEFAULT_SIZE = 20;

    public Pageable toPageable() {
        return PageRequest.of(
                page == null ? DEFAULT_PAGE : page,
                size == null ? DEFAULT_SIZE : size,
                Sort.by(Sort.Order.asc("listPrice"), Sort.Order.desc("tokenId")));
    }
}
