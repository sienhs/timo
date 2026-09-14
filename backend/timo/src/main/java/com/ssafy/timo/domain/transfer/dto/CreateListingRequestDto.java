package com.ssafy.timo.domain.transfer.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

/**
 * 양도 등록 요청.
 *
 * <p>{@code ticketId} 는 응답에는 싣지 않는 값이지만 요청에서는 받는다. 판매자는 자기 티켓의
 * 식별자를 이미 알고 있고, 남의 것을 넣어도 소유자 검증에서 막힌다. 역추적 위험은 "남의 매물
 * 응답에서 그 매물의 티켓이 무엇인지 알게 되는 것"이라 요청 방향과는 무관하다.
 *
 * <p>{@code price} 가 정가 이하인지는 형식 검증이 아니라 티켓의 정가를 알아야 해서 서비스가
 * 판단한다({@code ListPriceExceedsFacePriceException}). 0 은 무상 전송이라 성립하지 않는다.
 */
public record CreateListingRequestDto(

        @NotNull(message = "티켓 ID는 필수입니다.")
        @Positive(message = "티켓 ID는 1 이상이어야 합니다.")
        Long ticketId,

        @NotNull(message = "등록가는 필수입니다.")
        @Positive(message = "등록가는 1 이상이어야 합니다.")
        Integer price
) {
}
