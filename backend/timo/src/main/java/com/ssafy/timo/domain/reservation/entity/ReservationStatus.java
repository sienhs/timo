package com.ssafy.timo.domain.reservation.entity;

/**
 * 주문(예매)의 발행 상태.
 *
 * <p>좌석 배정과 잔액 차감은 주문 확정 시점에 오프체인에서 끝나고, 온체인 티켓 발행은 비동기로 따라간다.
 * 그래서 주문은 "결제됐는가" 가 아니라 "티켓이 나왔는가" 를 상태로 든다. 자세한 흐름은
 * {@code backend/docs/BE_RESERVATION_DOMAIN_DRAFT.md} 참고.
 *
 * <pre>
 * PENDING_MINT ──(mint 성공)──▶ MINTED
 *      └──(3회 실패)──▶ MINT_FAILED ──(보상 환불)──▶ REFUNDED
 * </pre>
 */
public enum ReservationStatus {

    /** 주문 확정. 좌석은 배정됐고 잔액은 차감됐지만 온체인 발행은 아직이다. */
    PENDING_MINT,
    /** 온체인 티켓 발행 완료. {@code tokenId} 가 있다. */
    MINTED,
    /** 발행 재시도를 모두 실패했다. 보상 환불이 진행 중이다. */
    MINT_FAILED,
    /** 보상 환불까지 끝났다. 좌석은 회수됐고 결제 금액은 잔액으로 돌아갔다. */
    REFUNDED,
    /** 회원이 취소했다. 티켓은 회수({@code REVOKED})되고 정가가 전액 환원됐다. */
    CANCELLED
}
