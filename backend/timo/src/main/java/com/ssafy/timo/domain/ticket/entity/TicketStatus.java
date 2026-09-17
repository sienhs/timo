package com.ssafy.timo.domain.ticket.entity;

/**
 * 티켓(온체인 발행) 상태.
 *
 * <p>{@link com.ssafy.timo.domain.reservation.entity.Reservation}은 "이 자리가 팔렸는가"만 안다
 * ({@code PAID}/{@code CANCELLED}). 발행이 어디까지 갔는지(대기·완료·실패·환불)는 이 enum, 즉
 * {@code Ticket} 쪽 관심사다.
 *
 * <pre>
 * PENDING_MINT ──(mint 성공)──▶ OWNED ──(입장)──▶ USED
 *      │                          ├──(회수)──▶ REVOKED
 *      │                          └──(양도 등록)──▶ LISTED
 *      └──(실패)──▶ MINT_FAILED ──(보상 환불)──▶ REFUNDED
 * </pre>
 */
public enum TicketStatus {

    /** 주문은 확정됐지만 온체인 발행은 아직. */
    PENDING_MINT,
    /** 발행 시도가 실패함. 보상(환불)이 필요하거나 진행 중. */
    MINT_FAILED,
    /** 보상 환불까지 끝남. */
    REFUNDED,
    /** 발행 완료, 정상 소유 중. */
    OWNED,
    /** 재판매 등록됨. */
    LISTED,
    /** 입장 처리 완료. */
    USED,
    /** 예매 취소 등으로 회수됨. */
    REVOKED
}
