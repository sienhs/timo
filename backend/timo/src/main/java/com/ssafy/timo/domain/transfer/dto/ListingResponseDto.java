package com.ssafy.timo.domain.transfer.dto;

import java.time.LocalDateTime;

/**
 * 양도 매물 한 건. 등록 응답과 매물 목록 항목이 같은 모양이다.
 *
 * <p>{@code mine} 이 true 면 내가 올린 매물이다. 화면은 이 매물에 구매 버튼 대신 등록 취소 버튼을 보여 준다.
 * {@code discountRate} 는 정가 대비 할인율(%)이다. 화면이 계산해도 되지만 정렬·표기가 흔들리지 않게 서버가 준다.
 *
 * <p>판매자는 지갑 주소로만 드러난다. 개인정보는 온체인에도, 이 응답에도 없다.
 */
public record ListingResponseDto(
        String tokenId,
        Long concertId,
        String concertTitle,
        String posterImageUrl,
        LocalDateTime startDate,
        String venueName,
        Long seatId,
        Long sectionId,
        String sectionName,
        int seatNo,
        int seatCol,
        long facePrice,
        long listPrice,
        int discountRate,
        String sellerAddress,
        boolean mine,
        LocalDateTime listedAt
) {
}
