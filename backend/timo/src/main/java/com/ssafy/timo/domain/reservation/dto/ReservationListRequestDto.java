package com.ssafy.timo.domain.reservation.dto;

import com.ssafy.timo.domain.reservation.entity.ReservationStatus;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

/**
 * 내 주문 목록 조회 조건. 목록 API 컨벤션(BE_CODE_CONVENTION 4장)을 따른다.
 *
 * <p>정렬은 최근 주문순 하나뿐이라 enum 을 두지 않았다. 필요해지면 {@code ConcertSortType} 처럼 추가한다.
 */
public record ReservationListRequestDto(

        @Min(value = 0, message = "페이지 번호는 0 이상이어야 합니다.")
        Integer page,

        @Min(value = 1, message = "페이지 크기는 1 이상이어야 합니다.")
        @Max(value = MAX_SIZE, message = "페이지 크기는 " + MAX_SIZE + " 이하여야 합니다.")
        Integer size,

        ReservationStatus status
) {
    private static final int MAX_SIZE = 100;
    private static final int DEFAULT_PAGE = 0;
    private static final int DEFAULT_SIZE = 20;

    public Pageable toPageable() {
        return PageRequest.of(
                page == null ? DEFAULT_PAGE : page,
                size == null ? DEFAULT_SIZE : size,
                Sort.by(Sort.Order.desc("createdAt"), Sort.Order.desc("id")));
    }
}
