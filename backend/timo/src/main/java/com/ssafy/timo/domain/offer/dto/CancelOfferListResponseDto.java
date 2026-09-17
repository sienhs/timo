package com.ssafy.timo.domain.offer.dto;

import com.ssafy.timo.domain.offer.entity.CancelOffer;
import com.ssafy.timo.global.storage.ImageStorage;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 내게 열린 취소표 구매 기회 목록.
 *
 * <p><b>페이징하지 않는다.</b> 열린 기회는 공연당 회원당 하나뿐이고 1시간이면 사라지므로, 한 회원이
 * 동시에 들고 있는 수는 찜한 공연 수를 넘지 못하고 실제로는 한두 건이다. 응답 크기를 묶는 것은 이
 * 규칙이다(BE 컨벤션 4.5).
 *
 * @param serverTime 판정에 쓴 서버 시각. 앱은 기기 시계가 아니라 이 값과 {@code expiresAt} 의 차이로 남은 시간을 그린다
 */
public record CancelOfferListResponseDto(List<CancelOfferSummaryResponseDto> offers, LocalDateTime serverTime) {

    public static CancelOfferListResponseDto from(List<CancelOffer> offers, LocalDateTime now, ImageStorage imageStorage) {
        return new CancelOfferListResponseDto(
                offers.stream().map(offer -> CancelOfferSummaryResponseDto.from(offer, imageStorage)).toList(),
                now);
    }
}
