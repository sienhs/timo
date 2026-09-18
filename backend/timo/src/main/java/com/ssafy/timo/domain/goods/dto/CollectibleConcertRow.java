package com.ssafy.timo.domain.goods.dto;

import java.time.LocalDateTime;

/**
 * 굿즈를 만들 수 있는 공연 한 줄. {@code GoodsRepository.findCollectibleConcerts} 의 프로젝션이다.
 *
 * <p>네이티브 SQL 이라 <b>컬럼 별칭이 곧 메서드 이름이다.</b> {@code MyTicketRow} 와 같은 방식이다.
 */
public interface CollectibleConcertRow {

    Long getTicketId();

    Long getConcertId();

    String getTitle();

    /** 출연 아티스트 이름을 {@code ", "} 로 이은 한 줄. 아티스트가 없으면 {@code null}. */
    String getArtist();

    LocalDateTime getStartDate();

    String getVenue();

    /** 저장소 키다. URL 변환은 {@code ImageStorage} 가 한다. */
    String getPosterImageKey();

    /** 이 티켓으로 이미 만든 굿즈. 없으면 {@code null}. */
    Long getGoodsId();
}
