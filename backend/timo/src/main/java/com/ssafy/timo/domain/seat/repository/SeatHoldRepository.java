package com.ssafy.timo.domain.seat.repository;

import com.ssafy.timo.domain.seat.entity.SeatHold;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.Optional;

@Repository
public interface SeatHoldRepository extends JpaRepository<SeatHold, Long> {

    /**
     * 만료된 선점은 INSERT 전에 끝내야 유효 선점 유니크 키를 비운다. 단, 매 선점마다
     * `UPDATE ... WHERE`를 실행하면 InnoDB가 존재하지 않는 키 범위까지 잠가 서로 다른
     * 좌석 요청도 deadlock 날 수 있다. 먼저 일반 조회로 대상이 실제로 있을 때만 엔티티를 갱신한다.
     */
    @Query("""
            select h
            from SeatHold h
            where h.concert.id = :concertId
              and h.activeSeat = :seatId
              and h.status = com.ssafy.timo.domain.seat.entity.SeatHoldStatus.HELD
              and h.expiresAt <= :now
            """)
    Optional<SeatHold> findExpiredForSeat(@Param("concertId") Long concertId,
                                          @Param("seatId") Long seatId,
                                          @Param("now") LocalDateTime now);

    /** 같은 회원의 만료 선점이 새 선점의 회원 유니크 제약을 막지 않게 찾는다. */
    @Query("""
            select h
            from SeatHold h
            where h.concert.id = :concertId
              and h.activeMember = :memberId
              and h.status = com.ssafy.timo.domain.seat.entity.SeatHoldStatus.HELD
              and h.expiresAt <= :now
            """)
    Optional<SeatHold> findExpiredForMember(@Param("concertId") Long concertId,
                                            @Param("memberId") Long memberId,
                                            @Param("now") LocalDateTime now);

    /** 이 공연에서 이 좌석을 붙들고 있는 유효한 선점. */
    @Query("""
            select h
            from SeatHold h
            where h.concert.id = :concertId
              and h.seat.id = :seatId
              and h.status = com.ssafy.timo.domain.seat.entity.SeatHoldStatus.HELD
              and h.expiresAt > :now
            """)
    Optional<SeatHold> findActive(@Param("concertId") Long concertId,
                                  @Param("seatId") Long seatId,
                                  @Param("now") LocalDateTime now);

    /**
     * 이 공연에서 이 회원이 붙들고 있는 유효한 선점.
     *
     * <p>"한 계정은 한 공연에서 좌석 하나만" 규칙 때문에 최대 한 건이다. 새 좌석을 잡기 전에 이전
     * 선점을 풀어 주는 데 쓴다 — 풀지 않고 넣으면 {@code uk_hold_member} 에 걸린다.
     */
    @Query("""
            select h
            from SeatHold h
            where h.concert.id = :concertId
              and h.member.id = :memberId
              and h.status = com.ssafy.timo.domain.seat.entity.SeatHoldStatus.HELD
              and h.expiresAt > :now
            """)
    Optional<SeatHold> findActiveOfMember(@Param("concertId") Long concertId,
                                          @Param("memberId") Long memberId,
                                          @Param("now") LocalDateTime now);
}
