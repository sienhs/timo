package com.ssafy.timo.domain.alarm.dto;

/**
 * "이 회원이 이 공연의 알림을 신청했다" 한 건. 여러 공연을 한 번에 물을 때 어느 공연의 신청인지 함께
 * 돌려주려는 행이다. 양도 매물 알림은 회원마다 신청한 공연들을 모아 한 건으로 묶어야 해서 두 값이 다 필요하다.
 */
public interface AlarmedConcertRow {

    Long getMemberId();

    Long getConcertId();
}
