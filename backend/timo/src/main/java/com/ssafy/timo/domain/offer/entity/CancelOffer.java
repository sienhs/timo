package com.ssafy.timo.domain.offer.entity;

import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.seat.entity.Seat;
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
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 취소표 구매 기회. 예매가 취소되면 그 공연을 찜한 회원 중 한 명이 이 좌석을 1시간 동안 독점 예매할 수 있다.
 *
 * <p>기회는 <b>기록</b>이지 잠금이 아니다. 실제 결제 직전 잠금은 좌석 선점이 그대로 맡고, 이 행은
 * "누가 언제 뽑혔고 샀는지" 를 남긴다. 회수된 좌석의 잠금을 푸는 근거도 이 행이다 — 열린 기회가
 * 있으면 당첨자만, 없거나 지났으면 누구나 그 자리를 잡을 수 있다.
 *
 * <p>같은 좌석에 열린 기회는 하나뿐이다({@code uk_offer_seat_active}). 기한이 지난 행은 조회가 무시하지만
 * 유니크 재료로는 남아 있어, 다음 기회를 열기 전에 {@link OfferStatus#EXPIRED} 로 바꿔야 한다.
 */
@Getter
@Entity
@Table(name = "cancel_offer",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_offer_seat_active",
                columnNames = {"concert_id", "active_seat"}),
        // 내 기회 목록. 상태로 좁힌 뒤 기한을 본다.
        indexes = @Index(name = "idx_offer_member_status", columnList = "member_id, status"))
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class CancelOffer extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "offer_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "concert_id", nullable = false)
    private Concert concert;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "seat_id", nullable = false)
    private Seat seat;

    /** 당첨자. */
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "member_id", nullable = false)
    private Member member;

    /** 취소된 원 주문. 감사용이라 연관을 걸지 않는다. */
    @Column(name = "source_reservation_id", nullable = false)
    private Long sourceReservationId;

    @Column(name = "expires_at", nullable = false)
    private LocalDateTime expiresAt;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private OfferStatus status;

    /** 당첨자가 결제한 주문. {@link OfferStatus#ACCEPTED} 일 때만 있다. */
    @Column(name = "reservation_id")
    private Long reservationId;

    /**
     * {@code status='OFFERED'} 일 때만 좌석 id 를 갖는 생성 칼럼. {@code uk_offer_seat_active} 의 재료다.
     * 값은 DB 가 계산하므로 애플리케이션은 읽지도 쓰지도 않는다({@code Reservation.activeSeat} 와 같다).
     */
    @Column(name = "active_seat", insertable = false, updatable = false,
            columnDefinition = "BIGINT GENERATED ALWAYS AS (IF(status = 'OFFERED', seat_id, NULL)) STORED")
    private Long activeSeat;

    @Builder
    private CancelOffer(Concert concert, Seat seat, Member member, Long sourceReservationId, LocalDateTime expiresAt) {
        this.concert = concert;
        this.seat = seat;
        this.member = member;
        this.sourceReservationId = sourceReservationId;
        this.expiresAt = expiresAt;
        this.status = OfferStatus.OFFERED;
    }

    /** 열려 있고 기한 안인가. 상태만 보면 기한이 지난 행도 열린 것으로 보인다. */
    public boolean isActiveAt(LocalDateTime now) {
        return status == OfferStatus.OFFERED && expiresAt.isAfter(now);
    }

    public boolean isFor(Long memberId) {
        return member.getId().equals(memberId);
    }
}
