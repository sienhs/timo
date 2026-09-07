package com.ssafy.timo.domain.seat.entity;

import com.ssafy.timo.domain.venue.entity.Venue;
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

import java.util.List;

/**
 * 공연장의 좌석 구역. 등급과 가격은 좌석마다 다르지 않고 구역 단위로 정해진다.
 *
 * <p>{@code rowCount}, {@code seatPerRow} 는 좌석 배치도를 그릴 때 쓰는 격자 크기일 뿐, 좌석을 만드는
 * 근거가 아니다. 좌석은 언제나 {@link #createSeats(List)} 에 넘긴 자리 목록으로만 만들어진다. 통로 때문에
 * 중간이 비거나 행마다 좌석 수가 다른 배치가 있으므로 이 값이 곧 좌석 수라는 보장은 없고,
 * 실제 좌석 수는 {@code seatCount} 를 본다. 스탠딩처럼 격자로 표현되지 않는 구역은 둘 다 비어 있을 수 있어
 * {@code Integer} 로 둔다.
 *
 * <p>{@link Seat} 목록을 컬렉션으로 들고 있지 않다. 한 구역의 좌석이 수천 건이 될 수 있어
 * 구역을 읽을 때마다 딸려 오면 안 되고, 좌석은 언제나 구역 조건으로 조회하기 때문이다.
 */
@Getter
@Entity
@Table(name = "section",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_section_venue_name",
                columnNames = {"venue_id", "name"}))
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Section extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "section_id")
    private Long id;

    /** 구역 이름. 공연장 안에서 유일하다. (예: "1층 A블록") */
    @Column(name = "name", length = 50, nullable = false)
    private String name;

    @Enumerated(EnumType.STRING)
    @Column(name = "grade", nullable = false)
    private SeatGrade grade;

    @Column(name = "price", nullable = false)
    private int price;

    /** 이 구역에 실제로 등록된 좌석 수. 격자 크기가 아니라 만들어진 좌석 개수다. */
    @Column(name = "seat_count", nullable = false)
    private int seatCount;

    /** 좌석 배치도의 행 수. 스탠딩 등 격자가 아닌 구역은 비어 있다. */
    @Column(name = "row_count")
    private Integer rowCount;

    /** 좌석 배치도의 행당 자리 수. 스탠딩 등 격자가 아닌 구역은 비어 있다. */
    @Column(name = "seat_per_row")
    private Integer seatPerRow;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "venue_id", nullable = false)
    private Venue venue;

    /**
     * 생성 시점의 등급과 좌석 수는 외부에서 정하지 않는다.
     * 등급 구분이 생기기 전이므로 모든 구역은 {@link SeatGrade#COMMON} 이고,
     * {@code seatCount} 는 좌석을 실제로 등록할 때 채워진다.
     */
    @Builder
    public Section(String name,
                   int price,
                   Integer rowCount,
                   Integer seatPerRow,
                   Venue venue) {
        this.name = name;
        this.grade = SeatGrade.COMMON;
        this.price = price;
        this.seatCount = 0;
        this.rowCount = rowCount;
        this.seatPerRow = seatPerRow;
        this.venue = venue;
    }

    /**
     * 넘겨받은 자리마다 좌석을 만든다. 통로로 비는 자리나 행마다 다른 좌석 수처럼
     * 격자로 표현되지 않는 배치가 그대로 들어온다.
     *
     * <p>만들어진 개수를 그대로 {@code seatCount} 에 반영한다. 좌석 수를 따로 받지 않고 여기서 채우는 이유는,
     * 두 값이 어긋나면 잔여석 계산의 분모가 실제 좌석과 달라지기 때문이다.
     *
     * <p>돌려준 좌석은 아직 저장되지 않았다. 영속화는 호출한 쪽의 책임이다.
     *
     * @throws IllegalStateException 자리 목록이 비어 있는 경우. 요청으로 들어온 값은 그 전에
     *         Bean Validation 이 걸러내므로 이것은 마지막 방어선이다.
     */
    public List<Seat> createSeats(List<SeatPosition> positions) {
        if (positions == null || positions.isEmpty()) {
            throw new IllegalStateException(
                    "좌석 없는 구역은 등록할 수 없습니다. (sectionId=" + id + ")");
        }

        List<Seat> seats = positions.stream()
                .map(position -> Seat.builder()
                        .seatNo(position.seatNo())
                        .seatCol(position.seatCol())
                        .section(this)
                        .build())
                .toList();

        this.seatCount = seats.size();
        return seats;
    }
}
