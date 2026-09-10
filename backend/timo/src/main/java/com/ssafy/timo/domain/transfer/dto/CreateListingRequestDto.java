package com.ssafy.timo.domain.transfer.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

/**
 * 양도 등록 요청.
 *
 * <p>{@code tokenId} 는 uint256 이라 문자열이다. {@code askPrice} 가 정가 이하인지는 형식 검증이 아니라
 * 티켓의 정가를 알아야 해서 서비스가 판단한다({@code ListPriceExceedsFacePriceException}).
 * 0 은 무상 전송이라 성립하지 않는다.
 */
public record CreateListingRequestDto(

        @NotBlank(message = "티켓 ID는 필수입니다.")
        String tokenId,

        @NotNull(message = "등록가는 필수입니다.")
        @Positive(message = "등록가는 1 이상이어야 합니다.")
        Long askPrice
) {
}
