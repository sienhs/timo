package com.ssafy.timo.domain.goods.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

/**
 * 내 굿즈 목록 요청. 페이지 번호와 크기뿐이다.
 *
 * <p>정렬을 받지 않는다. 의미 있는 순서가 최신 순 하나뿐이고, 조회 문장 안에 고정돼 있어 넘기면
 * 뒤에 덧붙어 중복된다. {@code MyTicketListRequestDto} 와 같은 상한·기본값을 쓴다.
 */
public record GoodsListRequestDto(

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
                size == null ? DEFAULT_SIZE : size);
    }
}
