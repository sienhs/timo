package com.ssafy.timo.domain.alarm.entity;

/**
 * 공연 알림 신청의 종류. 종류마다 따로 신청하고 따로 해제한다.
 *
 * <p>DB 에는 이름이 문자열로 들어간다. 순서(ordinal) 로 저장하면 항목을 끼워 넣을 때 기존 행의 뜻이 바뀐다.
 */
public enum AlarmType {

    /** 예매 오픈 안내. 신청한 공연의 예매가 곧 열리면 알린다. */
    CONCERT_OPEN,

    /** 양도 매물 안내. 신청한 공연에 새 양도 매물이 올라오면 알린다. */
    MARKET_LISTING
}
