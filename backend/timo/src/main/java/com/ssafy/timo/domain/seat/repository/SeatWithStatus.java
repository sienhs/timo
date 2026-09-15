package com.ssafy.timo.domain.seat.repository;

import com.ssafy.timo.domain.seat.entity.SeatStatus;

/**
 * 좌석 하나와, 특정 공연에서 본 그 좌석의 상태.
 *
 * <p>조회 쿼리가 좌석에 선점·주문을 각각 LEFT JOIN 한 결과다. 붙은 행이 있으면 그 id 가 들어오고
 * 없으면 {@code null} 이다. 상태를 SQL 의 {@code case} 로 만들지 않고 id 두 개를 그대로 받아
 * {@link #status()} 에서 판정하는 이유는, 판정 규칙이 JPQL 문자열 안이 아니라 자바 코드에 있어야
 * 읽고 고치기 쉽기 때문이다.
 *
 * @param holdId               유효한 선점 행의 id. 없으면 {@code null}
 * @param reservationId        유효한(PAID) 주문 행의 id. 없으면 {@code null}
 * @param revokedReservationId 취소된(CANCELLED) 주문 행 중 하나의 id. 없으면 {@code null}. 여러 건이어도
 *                             "회수된 적이 있는가" 만 보면 되므로 어느 것인지는 상관없다
 */
public record SeatWithStatus(
        Long seatId,
        int seatNo,
        int seatCol,
        Long holdId,
        Long reservationId,
        Long revokedReservationId
) {

    /**
     * 이 공연에서 본 좌석 상태.
     *
     * <p>주문을 선점보다 먼저 본다. 주문 확정 직후 선점이 아직 {@code CONVERTED} 로 바뀌지 않은
     * 순간에도 팔린 자리는 팔린 것으로 보여야 한다.
     *
     * <p>회수는 예매 가능보다 먼저 본다. 취소된 적이 있는 자리는 재오픈 절차(스토리 35) 전까지 다시
     * 예매 가능으로 보이면 안 된다 — 그 절차가 생기기 전에는 이 판정이 영구적이다.
     */
    public SeatStatus status() {
        if (reservationId != null) {
            return SeatStatus.SOLD;
        }
        if (holdId != null) {
            return SeatStatus.HELD;
        }
        if (revokedReservationId != null) {
            return SeatStatus.REVOKED;
        }
        return SeatStatus.AVAILABLE;
    }

    public boolean isAvailable() {
        return status() == SeatStatus.AVAILABLE;
    }
}
