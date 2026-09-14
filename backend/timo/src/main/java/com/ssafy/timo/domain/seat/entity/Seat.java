package com.ssafy.timo.domain.seat.entity;

import com.ssafy.timo.global.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
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
 * <p>공연장에 속한 <b>마스터 데이터</b>다. 그 공연장에서 열리는 모든 공연이 같은 행을 공유한다.
 *
 * <p>그래서 판매 상태를 여기에 담지 않는다. 예전에는 {@code status} · {@code held_by_member_id} ·
 * {@code held_until} 컬럼이 있었는데, 좌석 행이 하나뿐이라 9/20 공연에서 팔린 자리가 9/21 공연
 * 좌석표에도 팔린 것으로 보였다. 지금은 선점을 {@link SeatHold}, 판매를
 * {@code Reservation} 이 공연별 행으로 들고, 좌석 상태는 그 둘에서 유도한다({@link SeatStatus}).
 *
 * <p>등급과 가격도 좌석이 아니라 {@link Section} 이 갖는다. 결과적으로 좌석이 자체적으로 갖는 것은
 * <b>자리의 위치뿐</b>이고, 한 번 등록되면 바뀌지 않는다.
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

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "section_id", nullable = false)
    private Section section;

    @Builder
    public Seat(int seatNo, int seatCol, Section section) {
        this.seatNo = seatNo;
        this.seatCol = seatCol;
        this.section = section;
    }
}
