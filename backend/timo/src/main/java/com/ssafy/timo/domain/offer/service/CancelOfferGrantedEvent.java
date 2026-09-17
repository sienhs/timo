package com.ssafy.timo.domain.offer.service;

import java.time.LocalDateTime;

/**
 * 취소표 구매 기회가 당첨자에게 주어졌다. <b>알림은 여기서 받아 보낸다.</b>
 *
 * <p>알림 담당이 리스너를 붙일 지점이다. 반드시 {@code @TransactionalEventListener(phase = AFTER_COMMIT)}
 * 로 받아야 한다 — 이 이벤트는 예매 취소 트랜잭션 안에서 발행되므로, 커밋 전에 받으면 취소가 롤백됐는데
 * 알림만 나간다. 비동기로 처리하려면 {@code ReservationSettlementService} 가 같은 문제를 푼 방식을 본다.
 *
 * <p>당첨자는 {@code GET /api/v1/offers/me} 로 남은 시간을 확인한다. 알림 본문에는 이 값들이면 충분하다.
 *
 * @param offerId   기회 식별자
 * @param memberId  당첨자
 * @param concertId 공연
 * @param seatId    좌석
 * @param expiresAt 구매 기한. 이 시각이 지나면 좌석은 누구나 예매할 수 있다
 */
public record CancelOfferGrantedEvent(Long offerId, Long memberId, Long concertId, Long seatId, LocalDateTime expiresAt) {
}
