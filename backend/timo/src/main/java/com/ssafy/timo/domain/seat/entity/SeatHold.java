package com.ssafy.timo.domain.seat.entity;

import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.member.entity.Member;
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
 * 좌석 선점 한 건. <b>공연별</b>로 잡힌다.
 *
 * <p>예전에는 선점이 좌석 행의 컬럼({@code held_by_member_id}, {@code held_until})이었다. 그러면
 * 좌석 하나에 선점도 하나뿐이라, 같은 공연장에서 열리는 다른 공연이 같은 자리를 동시에 팔 수 없었다.
 * 선점을 별도 행으로 빼고 {@code concert_id} 를 달아 공연마다 독립시킨다.
 *
 * <p>동시 선점은 <b>잠금이 아니라 유니크 제약</b>으로 막는다. 좌석 행에 비관적 락을 걸면 서로 다른
 * 공연의 선점 요청이 같은 좌석 행 앞에 줄을 서기 때문이다. 대신 INSERT 를 시도하고 충돌하면 진 것으로
 * 본다({@code uk_hold_seat}).
 *
 * <p>끝난 선점도 지우지 않는다. 상태만 바꿔 두면 어느 자리가 왜 풀렸는지가 이력으로 남는다.
 * 그래서 한 좌석에 여러 행이 쌓이고, 그중 {@link SeatHoldStatus#HELD} 인 것만 유효하다.
 *
 * <h2>유니크가 "유효한 행 하나" 만 거는 방법</h2>
 *
 * <p>{@code (concert_id, seat_id)} 에 그냥 유니크를 걸면 끝난 선점까지 걸려 재선점이 막힌다.
 * 그래서 생성 칼럼을 둔다 — {@code status='HELD'} 일 때만 좌석 id 를 갖고 아니면 {@code NULL} 이다.
 * MySQL 의 유니크 인덱스는 {@code NULL} 을 중복으로 보지 않으므로, <b>유효한 선점만</b> 유일해진다.
 *
 * <p>{@code uk_hold_member} 도 같은 방식으로 "한 계정은 한 공연에서 좌석 하나만" 을 DB 가 지킨다.
 */
@Getter
@Entity
@Table(name = "seat_hold",
        uniqueConstraints = {
                @UniqueConstraint(name = "uk_hold_seat", columnNames = {"concert_id", "active_seat"}),
                @UniqueConstraint(name = "uk_hold_member", columnNames = {"concert_id", "active_member"})},
        indexes = @Index(name = "ix_hold_expire", columnList = "status, expires_at"))
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class SeatHold extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "seat_hold_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "concert_id", nullable = false)
    private Concert concert;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "seat_id", nullable = false)
    private Seat seat;

    /** 선점자. */
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "member_id", nullable = false)
    private Member member;

    /** 선점이 유지되는 시각. 이 시각을 넘기면 효력이 없다. */
    @Column(name = "expires_at", nullable = false)
    private LocalDateTime expiresAt;

    /** 실제로 풀린 시각. {@link SeatHoldStatus#HELD} 인 동안은 비어 있다. */
    @Column(name = "released_at")
    private LocalDateTime releasedAt;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private SeatHoldStatus status;

    /**
     * {@code status='HELD'} 일 때만 좌석 id 를 갖는 생성 칼럼. {@code uk_hold_seat} 의 재료다.
     *
     * <p>값은 DB 가 계산하므로 애플리케이션은 읽지도 쓰지도 않는다({@code insertable/updatable = false}).
     * 필드로 두는 유일한 이유는 스키마 생성이 이 칼럼을 만들게 하기 위해서다.
     */
    @Column(name = "active_seat", insertable = false, updatable = false,
            columnDefinition = "BIGINT GENERATED ALWAYS AS (IF(status = 'HELD', seat_id, NULL)) STORED")
    private Long activeSeat;

    /** {@code status='HELD'} 일 때만 회원 id 를 갖는 생성 칼럼. {@code uk_hold_member} 의 재료다. */
    @Column(name = "active_member", insertable = false, updatable = false,
            columnDefinition = "BIGINT GENERATED ALWAYS AS (IF(status = 'HELD', member_id, NULL)) STORED")
    private Long activeMember;

    /** 갓 만들어진 선점은 언제나 {@link SeatHoldStatus#HELD} 이므로 상태는 외부에서 정하지 않는다. */
    @Builder
    private SeatHold(Concert concert, Seat seat, Member member, LocalDateTime expiresAt) {
        this.concert = concert;
        this.seat = seat;
        this.member = member;
        this.expiresAt = expiresAt;
        this.status = SeatHoldStatus.HELD;
    }

    /** 기준 시각에 아직 유효한 선점인지. 상태와 만료를 함께 본다. */
    public boolean isActiveAt(LocalDateTime now) {
        return status == SeatHoldStatus.HELD && expiresAt.isAfter(now);
    }

    public boolean isOwnedBy(Long memberId) {
        return member != null && member.getId().equals(memberId);
    }

    /**
     * 만료 시각을 미룬다. 이미 자기가 잡고 있는 자리를 다시 누른 경우에 쓴다.
     *
     * <p>행을 새로 만들지 않고 기존 행을 미루는 이유는, 새로 넣으면 자기 자신의 선점 때문에
     * {@code uk_hold_seat} 에 걸리기 때문이다.
     */
    public void extendTo(LocalDateTime expiresAt) {
        if (this.status != SeatHoldStatus.HELD) {
            return;
        }
        this.expiresAt = expiresAt;
    }

    /** 회원이 직접 취소했다. */
    public void release(LocalDateTime now) {
        finish(SeatHoldStatus.RELEASED, now);
    }

    /** 만료돼 정리됐다. */
    public void expire(LocalDateTime now) {
        finish(SeatHoldStatus.EXPIRED, now);
    }

    /** 주문 확정으로 넘어갔다. */
    public void convert(LocalDateTime now) {
        finish(SeatHoldStatus.CONVERTED, now);
    }

    /**
     * 선점을 끝낸다. 이미 끝난 선점은 최초 종료 사유와 시각을 유지한다.
     *
     * <p>덮어쓰지 않는 이유는, 만료 정리 배치와 회원의 취소 요청이 같은 행을 동시에 볼 수 있기
     * 때문이다. 나중에 도착한 쪽이 앞선 사유를 지우면 왜 풀렸는지가 흐려진다.
     */
    private void finish(SeatHoldStatus finished, LocalDateTime now) {
        if (this.status != SeatHoldStatus.HELD) {
            return;
        }
        this.status = finished;
        this.releasedAt = now;
    }
}
