package com.ssafy.timo.domain.reservation.service;

import com.ssafy.timo.domain.blockchain.ContractCallException;
import com.ssafy.timo.domain.blockchain.ContractClient;
import com.ssafy.timo.domain.blockchain.ContractRevertException;
import com.ssafy.timo.domain.blockchain.MintResult;
import com.ssafy.timo.domain.blockchain.TicketNftClient;
import com.ssafy.timo.domain.blockchain.TicketVaultClient;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.reservation.repository.ReservationRepository;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.seat.repository.SectionRepository;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import com.ssafy.timo.domain.wallet.service.WalletService;

import java.math.BigInteger;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.List;
import java.util.function.Supplier;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * {@link ReservationSettlementService}가 실제 트랜잭션 작업을 위임하는 협력 빈.
 *
 * <p>별도 빈으로 뽑은 이유가 있다 - {@code @TransactionalEventListener} 메서드에는
 * {@code @Transactional}을 직접 붙일 수 없고(스프링이 기동 시점에 막는다), 그렇다고 같은 클래스
 * 안에서 {@code this.method()}로 부르면 프록시를 안 거쳐 그 메서드의 {@code @Transactional}이
 * 조용히 무시된다(자기 호출 문제). 진짜 다른 빈을 거쳐야 트랜잭션 프록시가 실제로 걸린다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
class ReservationSettlementRunner {

    private static final int MAX_ATTEMPTS = 3;
    private static final long RETRY_DELAY_MS = 500;

    private final ReservationRepository reservationRepository;
    private final TicketRepository ticketRepository;
    private final SectionRepository sectionRepository;
    private final WalletService walletService;
    private final TicketVaultClient ticketVaultClient;
    private final TicketNftClient ticketNftClient;
    private final Clock clock;

    @Transactional
    void settle(Long reservationId) {
        Reservation reservation = reservationRepository.findById(reservationId)
                .orElseThrow(() -> new IllegalStateException("정산 대상 주문이 없습니다 (reservationId=" + reservationId + ")"));
        Ticket ticket = ticketRepository.findByReservationId(reservationId)
                .orElseThrow(() -> new IllegalStateException("정산 대상 티켓이 없습니다 (reservationId=" + reservationId + ")"));
        Concert concert = reservation.getConcert();
        Section section = reservation.getSeat().getSection();
        BigInteger price = BigInteger.valueOf(section.getPrice());
        int sectionIndex = sectionIndexOf(section);

        String buyerAddress = walletService.getAddress(reservation.getMember().getId());
        String organizerAddress = walletService.getAddress(concert.getOrganizer().getId());
        byte[] orderId = ContractClient.keccak256("reservation-" + reservationId);

        try {
            withRetry("차감", reservationId, () -> {
                ticketVaultClient.chargeForBooking(buyerAddress, organizerAddress, price, orderId);
                return null;
            });
        } catch (ContractCallException e) {
            log.warn("예매 차감 실패, 민팅 시도 안 함 (reservationId={})", reservationId, e);
            ticket.markMintFailed(e.getMessage());
            // 이 시도는 없었던 일이니 주문을 취소해 "1인 1매"·좌석 점유를 풀어 준다.
            // 안 풀면 이 회원은 이 공연을 영영 다시 예매할 수 없다.
            releaseNow(reservation);
            return;
        }

        try {
            MintResult minted = withRetry("민팅", reservationId, () -> ticketNftClient.mintTicket(
                    buyerAddress, concert.getShowId(), BigInteger.valueOf(reservation.getSeat().getId()), sectionIndex));
            ticket.markMinted(minted.tokenId(), minted.transactionHash());
        } catch (ContractCallException e) {
            log.error("차감은 됐는데 민팅 실패, 환불 시도함 (reservationId={})", reservationId, e);
            refundOrElseMarkFailed(reservation, buyerAddress, organizerAddress, reservationId, price, ticket, e.getMessage());
        }
    }

    /**
     * revert({@link ContractRevertException})는 재시도해도 결과가 같으므로 즉시 위로 던진다.
     * 그 외(RPC 타임아웃 등 일시적 실패)만 {@link #MAX_ATTEMPTS}번까지 짧게 대기하며 재시도한다.
     */
    private <T> T withRetry(String action, Long reservationId, Supplier<T> call) {
        for (int attempt = 1; ; attempt++) {
            try {
                return call.get();
            } catch (ContractRevertException e) {
                throw e;
            } catch (ContractCallException e) {
                if (attempt >= MAX_ATTEMPTS) {
                    throw e;
                }
                log.warn("{} 일시적 실패, 재시도 {}/{} (reservationId={})", action, attempt, MAX_ATTEMPTS, reservationId, e);
                sleep();
            }
        }
    }

    private void sleep() {
        try {
            Thread.sleep(RETRY_DELAY_MS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new ContractCallException("재시도 대기 중 인터럽트됨", e);
        }
    }

    /**
     * {@code ShowRegistry}에 올라간 구역 가격 배열에서 이 구역이 몇 번째(0-4)인지 찾는다. 순서는
     * 반드시 {@link SectionRepository#findAllByVenueIdOrderByIdAsc}가 주는 순서와 같아야 한다 -
     * 온체인 등록 때도 같은 메서드로 구한 순서를 썼기 때문이다(LocalDataSeeder 참고).
     */
    private int sectionIndexOf(Section section) {
        List<Section> sections = sectionRepository.findAllByVenueIdOrderByIdAsc(section.getVenue().getId());
        for (int i = 0; i < sections.size(); i++) {
            if (sections.get(i).getId().equals(section.getId())) {
                return i;
            }
        }
        throw new IllegalStateException(
                "구역이 소속 공연장의 구역 목록에 없습니다 (sectionId=" + section.getId() + ", venueId=" + section.getVenue().getId() + ")");
    }

    /**
     * 좌석을 지연 없이 곧바로 돌려주며 취소한다.
     *
     * <p>사용자 취소({@code ReservationServiceImpl.cancel})는 3분 1초에서 15분 사이의 랜덤 지연을
     * 두지만 여기는 다르다. 결제나 발행이 실패해 <b>없었던 일로 되돌리는</b> 경로라, 지연을 두면
     * 시스템이 실패한 대가를 사용자가 기다림으로 치르게 된다. 바로 다시 시도할 수 있어야 한다.
     */
    private void releaseNow(Reservation reservation) {
        LocalDateTime now = LocalDateTime.now(clock);
        reservation.cancel(now, now);
    }

    private void refundOrElseMarkFailed(Reservation reservation, String buyerAddress, String organizerAddress, Long reservationId,
                                        BigInteger facePrice, Ticket ticket, String mintFailureReason) {
        byte[] refundRefId = ContractClient.keccak256("reservation-" + reservationId + ":refund");
        try {
            withRetry("환불", reservationId, () -> {
                ticketVaultClient.refund(buyerAddress, organizerAddress, facePrice, refundRefId);
                return null;
            });
            ticket.markRefunded(mintFailureReason);
            // 환불까지 끝나 돈은 원래대로다 - 위와 같은 이유로 주문도 취소해 다시 시도할 수 있게 한다.
            releaseNow(reservation);
        } catch (ContractCallException refundError) {
            // 환불조차 실패하면 돈이 어중간하게 걸린 상태다. 여기서 함부로 취소하면 "1인 1매"가
            // 풀려 버려 같은 회원이 또 예매할 수 있게 되는데, 실제로는 아직 안 끝난 결제가 남아
            // 있으니 수동으로 확인하기 전까진 PAID로 묶어 둬야 한다.
            log.error("환불도 실패함, 수동 개입 필요 (reservationId={})", reservationId, refundError);
            ticket.markMintFailed(mintFailureReason + " / 환불 실패: " + refundError.getMessage());
        }
    }
}
