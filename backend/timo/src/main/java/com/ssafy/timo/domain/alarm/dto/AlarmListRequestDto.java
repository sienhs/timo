package com.ssafy.timo.domain.alarm.dto;

import com.ssafy.timo.domain.alarm.entity.AlarmType;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

/**
 * 내 알림 신청 공연 목록 요청. 어느 종류의 신청인지와 페이지 번호, 크기를 받는다.
 *
 * <p>종류는 필수다. 종류마다 따로 신청하므로 "어느 알림" 인지 없이는 목록의 뜻이 정해지지 않는다.
 *
 * <p>정렬을 받지 않는다. 의미 있는 순서가 최근 신청한 순 하나뿐이고 그 정렬은 쿼리 안에 있다.
 */
public record AlarmListRequestDto(
        @NotNull(message = "알림 종류는 필수입니다.")
        AlarmType type,

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
