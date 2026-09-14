package com.ssafy.timo.domain.transfer.dto;

import java.time.LocalDateTime;

/**
 * 양도 매물이 올라와 있는 공연 하나의 요약.
 *
 * <p>공연마다 <b>매물 수와 최저가만</b> 준다. 개별 매물은 콘서트별 매물 조회에서 받는다.
 * 상위 묶음의 목록에 개별 항목을 실으면 응답이 매물 수에 비례해 커진다.
 *
 * <p>{@code listingCount} 는 지금 구매 가능한({@code LISTED}) 매물만 센다. 집계는 공연마다
 * 세지 말고 {@code group by} 한 번으로 모은다 — 묶음 수만큼 count 쿼리를 날리면 N+1 이다.
 *
 * <p>{@code LISTED} 매물이 하나도 없는 공연은 목록에 나오지 않는다. 매물이 0 인 행을 내보내면
 * 사용자가 들어가 봐야 빈 화면이다.
 */
public record MarketConcertSummaryResponseDto(
        Long concertId,
        String title,
        String posterImageUrl,
        LocalDateTime startDate,
        LocalDateTime endDate,
        String venueName,
        long listingCount,
        int lowestPrice
) {
}
