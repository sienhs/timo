package com.ssafy.timo.domain.seat.repository;

import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.SeatStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;

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
     * 여러 구역의 특정 상태 좌석 수를 한 번에 센다.
     *
     * <p>해당 상태의 좌석이 하나도 없는 구역은 결과에 포함되지 않는다.
     */
    @Query("""
            select new com.ssafy.timo.domain.seat.repository.SectionAvailableCount(
                       s.section.id, count(s))
            from Seat s
            where s.section.id in :sectionIds
              and s.status = :status
            group by s.section.id
            """)
    List<SectionAvailableCount> countByStatusGroupedBySection(
            @Param("sectionIds") Collection<Long> sectionIds,
            @Param("status") SeatStatus status);
}
