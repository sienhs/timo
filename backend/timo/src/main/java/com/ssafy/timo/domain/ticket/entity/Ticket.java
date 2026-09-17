package com.ssafy.timo.domain.ticket.entity;

import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.global.entity.BaseEntity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;

import java.math.BigInteger;

import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * {@link Reservation} 하나(주문 확정)가 실제로 온체인 발행되기까지의 진행 상태와, 발행된 뒤의
 * 소유권 기록. {@code Reservation}이 생성되는 트랜잭션 안에서 {@link TicketStatus#PENDING_MINT}로
 * 함께 만들어지고, 비동기 정산({@code ReservationSettlementService})이 그 뒤를 이어받는다.
 *
 * <p>누가/어느 공연/어느 좌석인지는 다시 들고 있지 않는다 - {@link #getReservation()}을 거친다.
 * 정가도 마찬가지로 {@code Reservation.getSeat().getSection().getPrice()}를 그때그때 읽는다
 * (발행 이후 정가는 바뀌지 않는다는 전제).
 *
 * <p>{@code tokenId}가 있다고 그대로 믿고 온체인 트랜잭션(입장 처리, 재판매 등)을 보내면 안 된다.
 * DB가 우연히 또는 의도적으로 틀렸을 가능성을 배제할 수 없는 캐시일 뿐이라, 실제 영향이 있는 액션
 * 직전엔 항상 체인에서 {@code ownerOf(tokenId)} 등으로 다시 확인해야 한다.
 */
@Getter
@Entity
@Table(name = "ticket",
        uniqueConstraints = {
                @UniqueConstraint(name = "uk_ticket_token_id", columnNames = "token_id"),
                @UniqueConstraint(name = "uk_ticket_reservation", columnNames = "reservation_id")
        })
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Ticket extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "ticket_id")
    private Long id;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "reservation_id", nullable = false)
    private Reservation reservation;

    /** 온체인 NFT의 tokenId. 발행 성공 전엔 null이다. */
    @Column(name = "token_id")
    private BigInteger tokenId;

    @Column(name = "mint_tx_hash", length = 66)
    private String mintTxHash;

    /** 발행 시도 횟수. 실패해도 자동으로 재시도하진 않는다 - 지금은 실패 원인을 남기는 것까지만 한다. */
    @Column(name = "mint_attempt_count", nullable = false)
    private int mintAttemptCount;

    /** {@link TicketStatus#MINT_FAILED}·{@link TicketStatus#REFUNDED}일 때만 값이 있다. */
    @Column(name = "failure_reason", length = 500)
    private String failureReason;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false)
    private TicketStatus status;

    /** 주문이 확정되면 항상 {@link TicketStatus#PENDING_MINT}로 시작하므로 상태는 외부에서 정하지 않는다. */
    @Builder
    private Ticket(Reservation reservation) {
        this.reservation = reservation;
        this.status = TicketStatus.PENDING_MINT;
        this.mintAttemptCount = 0;
    }

    /** 발행이 실제로 성공했을 때. */
    public void markMinted(BigInteger tokenId, String mintTxHash) {
        this.status = TicketStatus.OWNED;
        this.tokenId = tokenId;
        this.mintTxHash = mintTxHash;
        this.mintAttemptCount++;
    }

    /** 발행 시도가 실패했을 때(아직 보상 환불 전). */
    public void markMintFailed(String reason) {
        this.status = TicketStatus.MINT_FAILED;
        this.failureReason = reason;
        this.mintAttemptCount++;
    }

    /** 잔액 차감까진 됐는데 발행이 실패해, 보상 환불까지 끝났을 때. */
    public void markRefunded(String reason) {
        this.status = TicketStatus.REFUNDED;
        this.failureReason = reason;
    }

    /** 예매 취소로 회수한다. 온체인 {@code revoke}는 소유자를 custodyVault로 옮긴다. */
    public void revoke() {
        this.status = TicketStatus.REVOKED;
    }
}
