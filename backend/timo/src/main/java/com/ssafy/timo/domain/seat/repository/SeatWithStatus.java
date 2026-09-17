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
 * @param holdId        유효한 선점 행의 id. 없으면 {@code null}
 * @param reservationId 유효한(PAID) 주문 행의 id. 없으면 {@code null}
 * @param offerId       열려 있는 취소표 구매 기회의 id. 없으면 {@code null}. 당첨자만 이 자리를 잡을 수 있어
 *                      남에게는 선점과 같다
 */
public record SeatWithStatus(
        Long seatId,
        int seatNo,
        int seatCol,
        Long holdId,
        Long reservationId,
        Long offerId
) {

    /**
     * 이 공연에서 본 좌석 상태.
     *
     * <p>주문을 선점보다 먼저 본다. 주문 확정 직후 선점이 아직 {@code CONVERTED} 로 바뀌지 않은
     * 순간에도 팔린 자리는 팔린 것으로 보여야 한다.
     *
     * <p>열린 구매 기회는 선점으로 보인다. 당첨자 한 사람만 잡을 수 있는 자리라 남에게는 잡힌 자리와
     * 같고, 당첨자는 배치도가 아니라 내 기회 목록에서 이 자리로 들어온다. 기회가 끝난 자리는 그냥 빈 자리다.
     */
    public SeatStatus status() {
        if (reservationId != null) {
            return SeatStatus.SOLD;
        }
        if (holdId != null || offerId != null) {
            return SeatStatus.HELD;
        }
        return SeatStatus.AVAILABLE;
    }

    public boolean isAvailable() {
        return status() == SeatStatus.AVAILABLE;
    }
}
