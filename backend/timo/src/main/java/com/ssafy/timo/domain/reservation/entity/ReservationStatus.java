package com.ssafy.timo.domain.reservation.entity;

/**
 * 주문(예매)의 상태.
 *
 * <pre>
 * PAID ──(취소)──▶ CANCELLED
 * </pre>
 *
 * <p>{@link #PAID} 만 자리를 붙들고 있다. 취소된 주문은 좌석을 놓아 준다 — 좌석 상태를 유도할 때
 * {@link #PAID} 인지만 보는 이유다({@code SeatStatus}).
 *
 * <p>온체인 발행 진행 상태(발행 대기·발행 완료·발행 실패·보상 환불)는 여기에 담지 않는다. 주문은
 * "이 자리가 팔렸는가" 만 알면 되고, 발행이 어디까지 갔는지는 티켓 쪽 관심사다. 둘을 한 enum 에
 * 섞으면 좌석 상태 유도가 발행 재시도 상태까지 알아야 한다.
 */
public enum ReservationStatus {

    /** 결제 완료. 이 주문이 좌석을 붙들고 있다. */
    PAID,
    /** 취소됨. 좌석은 풀렸다. */
    CANCELLED
}
