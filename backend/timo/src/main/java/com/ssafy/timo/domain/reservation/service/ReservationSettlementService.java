package com.ssafy.timo.domain.reservation.service;

import com.ssafy.timo.domain.blockchain.ContractCallException;
import com.ssafy.timo.domain.blockchain.ContractClient;
import com.ssafy.timo.domain.blockchain.MintResult;
import com.ssafy.timo.domain.blockchain.TicketNftClient;
import com.ssafy.timo.domain.blockchain.TicketVaultClient;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.reservation.repository.ReservationRepository;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import com.ssafy.timo.domain.wallet.service.WalletService;
import java.math.BigInteger;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * 예매 확정 직후 큐에 올라온 {@link Reservation} 하나의 {@link Ticket}을 실제 체인에 반영한다 -
 * {@code chargeForBooking}으로 구매자 잔액을 주최자에게 넘기고, 성공하면 {@code mintTicket}으로
 * NFT를 발행한다.
 *
 * <p>이 서비스가 실패를 다루는 방식이 곧 {@code Ticket.tokenId}가 "체인을 그대로 믿으면 안 되는
 * 캐시"인 이유다 - 여기서 낙관적으로 성공을 가정하고 끝나는 것이 아니라, 정말로 온체인 트랜잭션이
 * 성공했을 때만 {@link Ticket#markMinted}를 부른다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ReservationSettlementService {

    private final ReservationRepository reservationRepository;
    private final TicketRepository ticketRepository;
    private final WalletService walletService;
    private final TicketVaultClient ticketVaultClient;
    private final TicketNftClient ticketNftClient;

    /**
     * {@link ReservationService#create}의 트랜잭션이 실제로 커밋된 뒤에만 실행된다
     * ({@code AFTER_COMMIT}) - 그래야 이 메서드가 새 트랜잭션(다른 스레드)에서 주문·티켓 행을
     * 다시 조회할 때 확실히 존재한다. 실패해도 예외를 밖으로 던지지 않는다 - 호출부는 이미 응답을
     * 끝낸 뒤라 던져 봐야 받을 사람이 없고, 실패 결과는 {@link Ticket#getStatus()}로 드러난다
     * (폴링·알림은 별도 관심사).
     */
    @Async("onChainSettlementExecutor")
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onReservationCreated(ReservationCreatedEvent event) {
        try {
            settleInTransaction(event.reservationId());
        } catch (Exception e) {
            log.error("주문 정산 실패 (reservationId={})", event.reservationId(), e);
        }
    }

    @Transactional
    void settleInTransaction(Long reservationId) {
        Reservation reservation = reservationRepository.findById(reservationId)
                .orElseThrow(() -> new IllegalStateException("정산 대상 주문이 없습니다 (reservationId=" + reservationId + ")"));
        Ticket ticket = ticketRepository.findByReservationId(reservationId)
                .orElseThrow(() -> new IllegalStateException("정산 대상 티켓이 없습니다 (reservationId=" + reservationId + ")"));
        Concert concert = reservation.getConcert();

        String buyerAddress = walletService.getAddress(reservation.getMember().getId());
        String organizerAddress = walletService.getAddress(concert.getOrganizer().getId());
        byte[] orderId = ContractClient.keccak256("reservation-" + reservationId);

        try {
            ticketVaultClient.chargeForBooking(buyerAddress, organizerAddress, concert.getFacePrice(), orderId);
        } catch (ContractCallException e) {
            log.warn("예매 차감 실패, 민팅 시도 안 함 (reservationId={})", reservationId, e);
            ticket.markMintFailed(e.getMessage());
            return;
        }

        try {
            MintResult minted = ticketNftClient.mintTicket(
                    buyerAddress, concert.getShowId(), BigInteger.valueOf(reservation.getSeat().getId()));
            ticket.markMinted(minted.tokenId(), minted.transactionHash());
        } catch (ContractCallException e) {
            log.error("차감은 됐는데 민팅 실패, 환불 시도함 (reservationId={})", reservationId, e);
            refundOrElseMarkFailed(buyerAddress, reservationId, concert.getFacePrice(), ticket, e.getMessage());
        }
    }

    private void refundOrElseMarkFailed(String buyerAddress, Long reservationId, BigInteger facePrice, Ticket ticket, String mintFailureReason) {
        byte[] refundRefId = ContractClient.keccak256("reservation-" + reservationId + ":refund");
        try {
            ticketVaultClient.refund(buyerAddress, facePrice, refundRefId);
            ticket.markRefunded(mintFailureReason);
        } catch (ContractCallException refundError) {
            log.error("환불도 실패함, 수동 개입 필요 (reservationId={})", reservationId, refundError);
            ticket.markMintFailed(mintFailureReason + " / 환불 실패: " + refundError.getMessage());
        }
    }
}
