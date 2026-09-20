package com.ssafy.timo.domain.concert.dto;

import java.time.LocalDateTime;

/**
 * 공연의 id, 제목, 예매 오픈 시각만. 예매 오픈 안내 스윕이 곧 열릴 공연을 찾을 때 쓴다.
 */
public interface ConcertOpenRow {

    Long getId();

    String getTitle();

    LocalDateTime getOpenAt();
}
