package com.ssafy.timo.domain.ticket.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

/**
 * 내 티켓 목록 요청. 페이지 번호와 크기뿐이다.
 *
 * <p>정렬을 받지 않는 이유는 의미 있는 순서가 하나뿐이어서다 — 최근에 내 것이 된 순. 열어 두면
 * 내부 모델 구조가 그대로 API 규약이 된다. {@link Pageable} 에 싣지도 않는다. 조회가 네이티브라
 * {@code order by} 가 문장 안에 있어 넘기면 뒤에 덧붙어 중복된다.
 *
 * <p>상태 필터도 없다. 지난 티켓과 취소된 티켓을 화면이 회색 카드로 남겨야 하기 때문이다.
 */
public record MyTicketListRequestDto(

        @Min(value = 0, message = "페이지 번호는 0 이상이어야 합니다.")
        Integer page,

        @Min(value = 1, message = "페이지 크기는 1 이상이어야 합니다.")
        @Max(value = MAX_SIZE, message = "페이지 크기는 " + MAX_SIZE + " 이하여야 합니다.")
        Integer size
) {
    private static final int MAX_SIZE = 100;
    private static final int DEFAULT_PAGE = 0;
    private static final int DEFAULT_SIZE = 20;

    /** 상한이 없으면 한 번의 요청으로 테이블 전체를 끌어갈 수 있어 {@code size} 를 100 으로 막는다. */
    public Pageable toPageable() {
        return PageRequest.of(
                page == null ? DEFAULT_PAGE : page,
                size == null ? DEFAULT_SIZE : size);
    }
}
