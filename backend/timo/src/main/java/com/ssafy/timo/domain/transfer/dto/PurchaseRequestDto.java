package com.ssafy.timo.domain.transfer.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

/**
 * 양도 구매 요청.
 *
 * <p>{@code expectedPrice} 는 사용자가 화면에서 본 가격이다. 서버의 등록가와 다르면 거부한다
 * ({@code ListingPriceMismatchException}). 등록가는 불변이지만 목록을 받아 둔 화면과 구매 요청
 * 사이에 시차가 있어 앱이 옛 가격을 들고 있을 수 있고, <b>사용자가 본 금액과 다른 금액이
 * 빠져나가면 안 된다.</b>
 *
 * <p>멱등키는 본문이 아니라 {@code Idempotency-Key} 헤더로 받는다. 재시도는 같은 키로 보낸다.
 */
public record PurchaseRequestDto(

        @NotNull(message = "예상 결제 금액은 필수입니다.")
        @Positive(message = "예상 결제 금액은 1 이상이어야 합니다.")
        Long expectedPrice
) {
}
