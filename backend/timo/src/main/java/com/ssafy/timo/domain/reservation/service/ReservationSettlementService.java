package com.ssafy.timo.domain.reservation.service;

import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * 예매 확정 직후 큐에 올라온 {@link Reservation} 하나의 {@link Ticket}을 실제 체인에 반영한다 -
 * {@code chargeForBooking}으로 구매자 잔액을 주최자에게 넘기고, 성공하면 {@code mintTicket}으로
 * NFT를 발행한다. 실제 작업은 {@link ReservationSettlementRunner}에 맡긴다.
 *
 * <p>이 서비스가 실패를 다루는 방식이 곧 {@code Ticket.tokenId}가 "체인을 그대로 믿으면 안 되는
 * 캐시"인 이유다 - 여기서 낙관적으로 성공을 가정하고 끝나는 것이 아니라, 정말로 온체인 트랜잭션이
 * 성공했을 때만 {@link Ticket#markMinted}를 부른다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ReservationSettlementService {

    private final ReservationSettlementRunner runner;

    /**
     * {@link ReservationService#create}의 트랜잭션이 실제로 커밋된 뒤에만 실행된다
     * ({@code AFTER_COMMIT}) - 그래야 {@link ReservationSettlementRunner}가 새 트랜잭션(다른
     * 스레드)에서 주문·티켓 행을 다시 조회할 때 확실히 존재한다. 실패해도 예외를 밖으로 던지지
     * 않는다 - 호출부는 이미 응답을 끝낸 뒤라 던져 봐야 받을 사람이 없고, 실패 결과는
     * {@link Ticket#getStatus()}로 드러난다(폴링·알림은 별도 관심사).
     *
     * <p>여기 직접 {@code @Transactional}을 붙이지 않는다 - {@code @TransactionalEventListener}
     * 메서드에 붙이면 스프링이 기동 시점에 예외를 던진다. 그래서 트랜잭션이 필요한 실제 작업은
     * 별도 빈({@link ReservationSettlementRunner})에 맡긴다.
     */
    @Async("onChainSettlementExecutor")
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onReservationCreated(ReservationCreatedEvent event) {
        try {
            runner.settle(event.reservationId());
        } catch (Exception e) {
            log.error("주문 정산 실패 (reservationId={})", event.reservationId(), e);
        }
    }
}
