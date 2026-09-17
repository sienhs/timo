package com.ssafy.timo.domain.wish.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

/**
 * 내 찜 목록 요청. 조건은 페이지 번호와 크기뿐이다.
 *
 * <p>정렬을 받지 않는다. 의미 있는 순서가 최근 찜한 순 하나뿐이고 그 정렬은 쿼리 안에 있다.
 */
public record WishListRequestDto(
        @Min(value = 0, message = "페이지 번호는 0 이상이어야 합니다.")
        Integer page,

        @Min(value = 1, message = "페이지 크기는 1 이상이어야 합니다.")
        @Max(value = MAX_SIZE, message = "페이지 크기는 " + MAX_SIZE + " 이하여야 합니다.")
        Integer size
) {
    private static final int MAX_SIZE = 100;
    private static final int DEFAULT_PAGE = 0;
    private static final int DEFAULT_SIZE = 20;

    public Pageable toPageable() {
        return PageRequest.of(
                page == null ? DEFAULT_PAGE : page,
                size == null ? DEFAULT_SIZE : size,
                Sort.unsorted());
    }
}
