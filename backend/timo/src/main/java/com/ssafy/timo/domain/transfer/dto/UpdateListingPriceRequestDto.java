package com.ssafy.timo.domain.transfer.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

/**
 * 양도 등록가 수정 요청.
 *
 * <p>바꿀 수 있는 값은 가격 하나뿐이라 {@code listingId} 도 받지 않는다 - 경로에 있다. 티켓·공연·좌석은
 * 등록 시점의 스냅샷이고 바뀔 이유가 없으며, 판매자를 본문으로 받지 않는 이유는
 * {@link CreateListingRequestDto} 와 같다.
 *
 * <p><b>증감이 아니라 절댓값이다.</b> 같은 요청을 두 번 보내도 결과가 같아야 재시도가 안전하다 -
 * 모바일 클라이언트는 응답을 받기 전에 끊기는 일이 흔하다.
 *
 * <p>새 가격이 정가 이하인지는 여기서 보지 않는다. 기준값은 그 매물이 들고 있는 등록 시점
 * 정가 스냅샷({@code ticket_listing.face_value})이라 서비스가 판단한다
 * ({@code ListPriceExceedsFacePriceException}). 0 은 무상 전송이라 성립하지 않는다.
 *
 * <p>{@code price} 가 {@code Long} 인 이유는 {@code TicketListing.faceValue} 주석을 본다 -
 * 정가의 단위가 미확정이라 wei 가 들어와도 받을 수 있어야 한다.
 */
public record UpdateListingPriceRequestDto(

        @NotNull(message = "등록가는 필수입니다.")
        @Positive(message = "등록가는 1 이상이어야 합니다.")
        Long price
) {
}
