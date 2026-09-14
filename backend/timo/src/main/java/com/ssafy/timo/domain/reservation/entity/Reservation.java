package com.ssafy.timo.domain.reservation.entity;

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
 * 주문(예매) 한 건. 어느 회원이 어느 공연의 어느 좌석을 샀는지다.
 *
 * <p>좌석은 공연장에 속한 마스터 데이터라 여러 공연이 같은 행을 공유한다. 그래서 주문은 좌석만으로
 * 성립하지 않고 <b>{@code concert_id} 를 반드시 함께</b> 든다. 예전 모델의 {@code event_type} ·
 * {@code event_ref_id} 같은 다형 참조 대신 공연을 직접 가리킨다 — 참조 대상이 공연 하나뿐인데
 * 종류 칼럼을 두면 FK 를 걸 수 없고 조인도 못 한다.
 *
 * <p>취소해도 행을 지우지 않는다. 상태만 {@link ReservationStatus#CANCELLED} 로 바꾸고
 * {@code cancelled_at} 을 남긴다. 그래야 같은 자리가 다시 팔린 것과 구분된다.
 *
 * <h2>같은 자리가 두 번 팔리지 않게 하는 방법</h2>
 *
 * <p>{@code (concert_id, seat_id)} 에 그냥 유니크를 걸면 취소된 주문까지 걸려 재판매가 막힌다.
 * 그래서 {@code status='PAID'} 일 때만 값을 갖는 생성 칼럼을 두고 거기에 유니크를 건다. MySQL 은
 * 유니크 인덱스에서 {@code NULL} 을 중복으로 보지 않으므로 <b>유효한 주문만</b> 유일해진다.
 *
 * <p>{@code uk_rsv_member} 는 같은 방식으로 "한 계정은 한 공연에서 1매만" 을 DB 가 지킨다.
 * 애플리케이션 검사와 달리 동시 요청에도 뚫리지 않는다.
 */
@Getter
@Entity
@Table(name = "reservation",
        uniqueConstraints = {
                @UniqueConstraint(name = "uk_rsv_seat", columnNames = {"concert_id", "active_seat"}),
                @UniqueConstraint(name = "uk_rsv_member", columnNames = {"concert_id", "active_member"})},
        indexes = @Index(name = "ix_rsv_member", columnList = "member_id, created_at"))
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Reservation extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "reservation_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "concert_id", nullable = false)
    private Concert concert;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "member_id", nullable = false)
    private Member member;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "seat_id", nullable = false)
    private Seat seat;

    /** 취소 시각. {@link ReservationStatus#PAID} 인 동안은 비어 있다. */
    @Column(name = "cancelled_at")
    private LocalDateTime cancelledAt;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private ReservationStatus status;

    /**
     * {@code status='PAID'} 일 때만 좌석 id 를 갖는 생성 칼럼. {@code uk_rsv_seat} 의 재료다.
     *
     * <p>값은 DB 가 계산하므로 애플리케이션은 읽지도 쓰지도 않는다. 필드로 두는 유일한 이유는
     * 스키마 생성이 이 칼럼을 만들게 하기 위해서다.
     */
    @Column(name = "active_seat", insertable = false, updatable = false,
            columnDefinition = "BIGINT GENERATED ALWAYS AS (IF(status = 'PAID', seat_id, NULL)) STORED")
    private Long activeSeat;

    /** {@code status='PAID'} 일 때만 회원 id 를 갖는 생성 칼럼. {@code uk_rsv_member} 의 재료다. */
    @Column(name = "active_member", insertable = false, updatable = false,
            columnDefinition = "BIGINT GENERATED ALWAYS AS (IF(status = 'PAID', member_id, NULL)) STORED")
    private Long activeMember;

    /** 갓 만들어진 주문은 언제나 {@link ReservationStatus#PAID} 이므로 상태는 외부에서 정하지 않는다. */
    @Builder
    private Reservation(Concert concert, Member member, Seat seat) {
        this.concert = concert;
        this.member = member;
        this.seat = seat;
        this.status = ReservationStatus.PAID;
    }

    public boolean isOwnedBy(Long memberId) {
        return member != null && member.getId().equals(memberId);
    }

    /** 이 주문이 아직 좌석을 붙들고 있는지. */
    public boolean isPaid() {
        return status == ReservationStatus.PAID;
    }

    /** 주문을 취소한다. 이미 취소된 주문은 최초 취소 시각을 유지한다. */
    public void cancel(LocalDateTime now) {
        if (this.status != ReservationStatus.PAID) {
            return;
        }
        this.status = ReservationStatus.CANCELLED;
        this.cancelledAt = now;
    }
}
