package com.ssafy.timo.domain.transfer.entity;

import com.ssafy.timo.global.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 양도 체결 한 건. 등록({@link TicketListing}) 하나에 체결은 하나다.
 *
 * <p>{@code listing_id} 의 유일 제약이 <b>이중 체결의 마지막 방어선</b>이다. 동시 구매는 매물의
 * 조건부 UPDATE 로 막지만 그것은 같은 DB 트랜잭션 안에서만 유효하고, 온체인 재시도가 섞이면
 * 뚫릴 여지가 있다. 비용은 인덱스 하나라 반드시 DB 제약으로 건다.
 *
 * <p>{@code sellerMemberId}·{@code buyerMemberId}·{@code ticketId} 는 <b>응답에 실으면 안 되는 값이다.</b>
 * 정산·CS·재양도 이력 추적에 필요해 남길 뿐이고, 판매자와 구매자는 서로를 알 수 없어야 한다.
 *
 * <p>{@link #price} 는 체결 시점의 스냅샷이다. 등록가는 불변이라 매물의 값과 같지만, 매물 행이
 * 나중에 어떻게 되든 이 거래의 금액은 여기 남아 있어야 정산이 성립한다.
 *
 * <p>{@link #status} 가 {@link TradeStatus#PENDING} 인 이유는 코인 전송과 NFT 소유권 이전이
 * DB 트랜잭션 밖이기 때문이다. <b>온체인 연동 전까지 모든 체결이 이 상태에 머문다.</b>
 */
@Getter
@Entity
@Table(name = "ticket_trade",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_ticket_trade_listing",
                columnNames = "listing_id"),
        indexes = {
                // 내 구매 내역.
                @Index(name = "idx_trade_buyer", columnList = "buyer_member_id, traded_at"),
                // 재양도 이력.
                @Index(name = "idx_trade_ticket", columnList = "ticket_id")})
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class TicketTrade extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "trade_id")
    private Long id;

    /**
     * 체결된 매물.
     *
     * <p>연관관계로 거는 이유는 내 구매 내역이 공연명·구역명 같은 표기값을 필요로 하는데,
     * 그것을 전부 여기에 또 복사하면 매물과 두 벌이 되기 때문이다. 매물은 이미 비정규화를
     * 마친 상태라 여기서 한 번만 타고 들어가면 된다.
     */
    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "listing_id", nullable = false)
    private TicketListing listing;

    /**
     * 양도된 티켓.
     *
     * <p>매물을 타고 가도 알 수 있지만 직접 들고 있다. 재양도 이력은 티켓 하나에 대한 조회인데,
     * 매물을 경유하면 이력이 길어질수록 조인이 늘어난다. <b>응답에 실으면 안 되는 값이다.</b>
     */
    @Column(name = "ticket_id", nullable = false)
    private Long ticketId;

    /** 판매자. <b>응답에 실으면 안 되는 값이다.</b> */
    @Column(name = "seller_member_id", nullable = false)
    private Long sellerMemberId;

    /** 구매자. <b>응답에 실으면 안 되는 값이다.</b> */
    @Column(name = "buyer_member_id", nullable = false)
    private Long buyerMemberId;

    /** 체결가 스냅샷. 등록가와 같다. {@code long} 인 이유는 {@code TicketListing.faceValue} 주석을 본다. */
    @Column(name = "price", nullable = false)
    private long price;

    @Column(name = "traded_at", nullable = false)
    private LocalDateTime tradedAt;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private TradeStatus status;

    @Builder(access = AccessLevel.PRIVATE)
    private TicketTrade(TicketListing listing,
                        Long ticketId,
                        Long sellerMemberId,
                        Long buyerMemberId,
                        long price,
                        LocalDateTime tradedAt) {
        this.listing = listing;
        this.ticketId = ticketId;
        this.sellerMemberId = sellerMemberId;
        this.buyerMemberId = buyerMemberId;
        this.price = price;
        this.tradedAt = tradedAt;
        this.status = TradeStatus.PENDING;
    }

    /**
     * 체결을 기록한다. 판매자·티켓·금액은 매물에서 가져오므로 따로 받지 않는다.
     *
     * <p>생성 시점의 상태는 언제나 {@link TradeStatus#PENDING} 이다. 온체인 전송이 남아 있는데
     * 완료로 적으면, 나중에 연동했을 때 이 값의 의미가 바뀐다.
     */
    public static TicketTrade record(TicketListing listing, Long buyerMemberId, LocalDateTime tradedAt) {
        return TicketTrade.builder()
                .listing(listing)
                .ticketId(listing.getTicketId())
                .sellerMemberId(listing.getSellerMemberId())
                .buyerMemberId(buyerMemberId)
                .price(listing.getPrice())
                .tradedAt(tradedAt)
                .build();
    }

    /**
     * 온체인 전송이 끝났음을 기록한다.
     *
     * <p><b>TODO</b>: 아직 부르는 곳이 없다. 코인 전송과 NFT 소유권 이전을 붙일 때
     * {@code TicketTransferService} 구현체가 호출한다.
     */
    public void confirm() {
        this.status = TradeStatus.CONFIRMED;
    }

    /**
     * 온체인 전송이 실패했음을 기록한다.
     *
     * <p><b>TODO</b>: 아직 부르는 곳이 없다. 실패했을 때 매물과 티켓을 어떻게 되돌릴지는
     * 온체인 방식이 정해져야 설계할 수 있다(보상 흐름 미정).
     */
    public void fail() {
        this.status = TradeStatus.FAILED;
    }
}
