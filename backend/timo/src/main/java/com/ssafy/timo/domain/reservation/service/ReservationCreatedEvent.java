package com.ssafy.timo.domain.reservation.service;

/**
 * {@link ReservationService#create}의 트랜잭션이 커밋된 뒤 발행된다.
 *
 * <p>{@link ReservationSettlementService}가 이 시점에만 반응해야 하는 이유: 커밋 전에 비동기로
 * 정산을 시작하면, 다른 스레드(다른 DB 커넥션)가 아직 커밋되지 않은 {@code Reservation} 행을
 * 조회하게 되는 경합이 생긴다.
 */
public record ReservationCreatedEvent(Long reservationId) {
}
