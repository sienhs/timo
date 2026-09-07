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

/**
 * 개별 좌석. 어느 구역의 몇 번째 행, 몇 번째 자리인지로 식별된다.
 *
 * <p>등급과 가격은 좌석이 아니라 {@link Section} 이 들고 있다. 좌석이 자체적으로 갖는 상태는
 * 판매 여부({@link SeatStatus}) 뿐이다.
 *
 * <p>상태를 바꾸는 메서드는 아직 두지 않았다. 선점·확정의 전이 규칙은 예매 기능과 함께 정해진다.
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

    /** 갓 등록된 좌석은 항상 예매 가능({@link SeatStatus#AVAILABLE})이므로 상태는 외부에서 정하지 않는다. */
    @Builder
    public Seat(int seatNo, int seatCol, Section section) {
        this.seatNo = seatNo;
        this.seatCol = seatCol;
        this.status = SeatStatus.AVAILABLE;
        this.section = section;
    }
}
