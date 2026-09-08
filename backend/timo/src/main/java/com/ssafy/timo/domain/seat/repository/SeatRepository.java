package com.ssafy.timo.domain.seat.repository;

import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.SeatStatus;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

@Repository
public interface SeatRepository extends JpaRepository<Seat, Long> {

    long countBySectionId(Long sectionId);

    /**
     * 한 구역의 좌석을 배치도 순서(행 -> 자리)로 읽는다.
     *
     * <p>구역은 이미 조회한 상태에서 부르므로 fetch join 하지 않는다. 좌석마다 구역을 다시 읽으면
     * 그게 N+1 이다.
     */
    List<Seat> findAllBySectionIdOrderBySeatNoAscSeatColAsc(Long sectionId);

    /**
     * 선점하려는 좌석을 행 잠금과 함께 읽는다.
     *
     * <p>{@code SELECT ... FOR UPDATE} 다. 잠그지 않고 "예매 가능인지 확인 -> 선점" 순서로 처리하면,
     * 두 요청이 같은 좌석을 동시에 확인하고 둘 다 선점에 성공한다. 확인과 선점이 한 잠금 안에서
     * 일어나야 "동일 좌석에 대한 동시 선점은 성립하지 않는다"가 지켜진다.
     *
     * <p>잠금은 트랜잭션이 끝날 때 풀리므로 이 메서드는 반드시 트랜잭션 안에서 부른다.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select s from Seat s where s.id = :id")
    Optional<Seat> findByIdForUpdate(@Param("id") Long id);

    /**
     * 이 회원이 지금 붙잡고 있는 좌석들. 만료된 선점은 제외한다.
     *
     * <p>"한 계정은 동시에 하나의 좌석만 선점한다"를 지키려고 이전 선점을 찾는 데 쓴다. 규칙상
     * 최대 한 건이지만, 과거에 어긋난 데이터가 남아 있어도 함께 풀 수 있도록 목록으로 받는다.
     */
    @Query("""
            select s
            from Seat s
            where s.heldByMemberId = :memberId
              and s.status = com.ssafy.timo.domain.seat.entity.SeatStatus.RESERVED
              and s.heldUntil > :now
              and s.id <> :excludedSeatId
            """)
    List<Seat> findActiveHoldsOfMember(@Param("memberId") Long memberId,
                                       @Param("now") LocalDateTime now,
                                       @Param("excludedSeatId") Long excludedSeatId);

    /**
     * 여러 구역의 예매 가능 좌석 수를 한 번에 센다.
     *
     * <p>{@code status} 가 예매 가능인 좌석에, <b>선점이 만료된 좌석</b>을 더해서 센다. 만료된 선점을
     * 정리하는 작업을 두지 않았으므로 {@code status} 만 보면 이미 풀린 자리를 팔 수 없는 것으로
     * 잘못 센다.
     *
     * <p>예매 가능 좌석이 하나도 없는 구역은 결과에 포함되지 않는다. 읽는 쪽에서 0 으로 채운다 —
     * 빠뜨리면 매진 구역이 목록에서 사라진다.
     */
    @Query("""
            select new com.ssafy.timo.domain.seat.repository.SectionAvailableCount(
                       s.section.id, count(s))
            from Seat s
            where s.section.id in :sectionIds
              and (s.status = com.ssafy.timo.domain.seat.entity.SeatStatus.AVAILABLE
                   or (s.status = com.ssafy.timo.domain.seat.entity.SeatStatus.RESERVED
                       and s.heldUntil <= :now))
            group by s.section.id
            """)
    List<SectionAvailableCount> countAvailableGroupedBySection(
            @Param("sectionIds") Collection<Long> sectionIds,
            @Param("now") LocalDateTime now);

    /** 상태만으로 세는 집계. 선점 만료를 따지지 않으므로 테스트·점검용으로만 쓴다. */
    long countBySectionIdAndStatus(Long sectionId, SeatStatus status);
}
