package com.ssafy.timo.domain.concert.dto;

import java.time.LocalDateTime;

/**
 * 공연의 id, 제목, 시작 시각만. 알림 스윕이 "지금 알릴 공연" 을 찾을 때 쓴다. 엔티티를 통째로 읽으면
 * 상세 설명 같은 큰 필드까지 딸려 오는데 알림에는 필요 없다.
 */
public interface ConcertStartRow {

    Long getId();

    String getTitle();

    LocalDateTime getStartDate();
}
