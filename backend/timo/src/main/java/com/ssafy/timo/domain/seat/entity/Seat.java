package com.ssafy.timo.domain.seat.entity;

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
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 개별 좌석. 어느 구역의 몇 번째 행, 몇 번째 자리인지로 식별된다.
 *
 * <p>등급과 가격은 좌석이 아니라 {@link Section} 이 들고 있다. 좌석이 자체적으로 갖는 상태는
 * 판매 여부({@link SeatStatus}) 뿐이다.
 *
 * <p>선점은 {@code status} 만으로 표현되지 않는다. 누가 언제까지 잡았는지를 함께 들고 있어야
 * 만료를 판정하고 "한 계정 동시 하나" 규칙을 지킬 수 있다.
 *
 * <p>만료된 선점은 별도 정리 없이 <b>읽는 시점에</b> 예매 가능으로 다룬다
 * ({@link #effectiveStatus(LocalDateTime)}). 그래서 {@code status} 컬럼 하나만 보면 실제 상태를
 * 알 수 없고, 좌석 상태를 판단하는 코드는 항상 기준 시각을 함께 넘겨야 한다.
 *
 * <p>결제 확정({@link SeatStatus#OCCUPIED})으로 가는 전이는 아직 없다. 예매 기능과 함께 정해진다.
 */
@Getter
@Entity
@Table(name = "seat",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_seat_section_position",
                columnNames = {"section_id", "seat_no", "seat_col"}))
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Seat extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "seat_id")
    private Long id;

    /** 구역 안에서의 행 번호. 1 부터 시작하고 {@link Section#getRowCount()} 를 넘지 않는다. */
    @Column(name = "seat_no", nullable = false)
    private int seatNo;

    /** 행 안에서의 자리 번호. 1 부터 시작하고 {@link Section#getSeatPerRow()} 를 넘지 않는다. */
    @Column(name = "seat_col", nullable = false)
    private int seatCol;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false)
    private SeatStatus status;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "section_id", nullable = false)
    private Section section;

    /**
     * 이 좌석을 선점한 회원.
     *
     * <p>연관관계로 매지 않고 id 만 들고 있다. 인증이 아직 목 구현이라 회원을 검증하지 않고,
     * 좌석 쪽에서 회원을 읽을 일도 없다. 인증이 붙을 때 함께 정리한다.
     */
    @Column(name = "held_by_member_id")
    private Long heldByMemberId;

    /** 선점이 유지되는 시각. 이 시각을 넘기면 선점은 효력이 없다. */
    @Column(name = "held_until")
    private LocalDateTime heldUntil;

    /** 갓 등록된 좌석은 항상 예매 가능({@link SeatStatus#AVAILABLE})이므로 상태는 외부에서 정하지 않는다. */
    @Builder
    public Seat(int seatNo, int seatCol, Section section) {
        this.seatNo = seatNo;
        this.seatCol = seatCol;
        this.status = SeatStatus.AVAILABLE;
        this.section = section;
    }

    /**
     * 기준 시각에서 본 실제 상태.
     *
     * <p>선점 시각이 지났으면 {@code status} 가 {@link SeatStatus#RESERVED} 여도 예매 가능이다.
     * 만료된 선점을 정리하는 작업을 따로 두지 않았으므로, 좌석 상태를 쓰는 쪽은 이 메서드를 거친다.
     */
    public SeatStatus effectiveStatus(LocalDateTime now) {
        return isHoldExpired(now) ? SeatStatus.AVAILABLE : this.status;
    }

    /** 기준 시각에 선점할 수 있는 좌석인지. 결제까지 끝난 좌석은 만료 개념이 없어 언제나 불가다. */
    public boolean isHoldableAt(LocalDateTime now) {
        return effectiveStatus(now) == SeatStatus.AVAILABLE;
    }

    /** 이 회원이 기준 시각에 이 좌석을 실제로 선점하고 있는지. */
    public boolean isHeldBy(Long memberId, LocalDateTime now) {
        return this.status == SeatStatus.RESERVED
                && !isHoldExpired(now)
                && memberId.equals(this.heldByMemberId);
    }

    /**
     * 좌석을 선점한다. 선점 가능 여부는 호출 쪽에서 행 잠금을 잡은 뒤 검사해 온다고 보고
     * 여기서 다시 확인하지 않는다.
     */
    public void hold(Long memberId, LocalDateTime until) {
        this.status = SeatStatus.RESERVED;
        this.heldByMemberId = memberId;
        this.heldUntil = until;
    }

    /** 선점을 풀어 예매 가능으로 되돌린다. 선점 흔적도 함께 지운다. */
    public void releaseHold() {
        this.status = SeatStatus.AVAILABLE;
        this.heldByMemberId = null;
        this.heldUntil = null;
    }

    private boolean isHoldExpired(LocalDateTime now) {
        return this.status == SeatStatus.RESERVED
                && this.heldUntil != null
                && !this.heldUntil.isAfter(now);
    }
}
