package com.ssafy.timo.domain.transfer.dto;

import java.time.LocalDateTime;

/**
 * 양도마켓 공연 목록의 집계 한 줄. 조회 전용 프로젝션이다.
 *
 * <p>응답 DTO({@link MarketConcertSummaryResponseDto})를 쿼리에서 바로 만들지 않는 이유는
 * 포스터 URL 때문이다. DB 에는 이미지 <b>키</b>만 있고 URL 은 {@code ImageStorage} 가 만든다.
 * 생성자 표현식으로 바로 조립하려면 쿼리가 URL 규칙까지 알아야 한다.
 *
 * <p>{@code listingCount} 와 {@code lowestPrice} 는 공연마다 세지 않고 {@code group by} 한 번으로
 * 모은다. 공연 수만큼 count 쿼리를 날리면 N+1 이다.
 */
public interface MarketConcertRow {

    Long getConcertId();

    String getTitle();

    String getPosterImageKey();

    LocalDateTime getStartDate();

    LocalDateTime getEndDate();

    String getVenueName();

    long getListingCount();

    long getLowestPrice();
}
