package com.ssafy.timo.domain.concert.entity;

/** {@link Concert#bookingBlockReason} 이 답하는 예매 불가 사유. 판정 순서 그대로 위에서 아래다. */
public enum BookingBlockReason {

    /** 예매 진행 중({@link ConcertStatus#ON_SALE})이 아니다. */
    NOT_ON_SALE,
    /** 아직 오픈 시각 전이다. 오픈·시작 시각이 없어 알 수 없는 경우도 포함한다. */
    NOT_OPEN,
    /** 공연 시작 {@link Concert#BOOKING_CUTOFF_HOURS}시간 전, 마감을 지났다. */
    CLOSED
}
