package com.ssafy.timo.domain.concert.entity;

/** 공연의 예매 상태. */
public enum ConcertStatus {

    /** 등록되었고 아직 예매가 열리지 않음 */
    SCHEDULED,
    /** 예매 진행 중 */
    ON_SALE,
    /** 잔여 좌석 소진 */
    SOLD_OUT,
    /** 공연 종료 */
    CLOSED,
    /** 공연 취소 */
    CANCELED
}
