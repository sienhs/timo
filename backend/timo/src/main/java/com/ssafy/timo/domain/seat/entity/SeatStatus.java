package com.ssafy.timo.domain.seat.entity;

/** 좌석의 판매 상태. */
public enum SeatStatus {

    /** 예매 가능 */
    AVAILABLE,
    /** 선점됨. 결제 대기 중이라 다른 사용자가 잡을 수 없다. */
    RESERVED,
    /** 결제까지 끝나 확정된 좌석 */
    OCCUPIED
}
