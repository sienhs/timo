package com.ssafy.timo.domain.seat.repository;

import com.ssafy.timo.domain.seat.entity.SeatHold;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.Optional;

@Repository
public interface SeatHoldRepository extends JpaRepository<SeatHold, Long> {

    /**
     * 새 선점에 충돌할 수 있는 만료 선점만 {@code EXPIRED} 로 정리한다.
     *
     * <p>유니크 제약은 공연별 좌석({@code uk_hold_seat})과 공연별 회원({@code uk_hold_member})에
     * 각각 걸려 있다. 따라서 요청 좌석의 만료 선점뿐 아니라, 같은 회원이 이 공연에서 잡았던 만료
     * 선점도 함께 정리해야 새 선점 INSERT가 유니크 제약에 막히지 않는다.
     *
     * <p>공연 전체의 만료 선점을 매 요청마다 갱신하지 않는다. 좌석·회원 유니크 인덱스를 각각 활용할 수
     * 있도록 두 메서드로 나눠, 선점 API의 불필요한 전역 UPDATE와 락 경합을 막는다.
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            update SeatHold h
               set h.status = com.ssafy.timo.domain.seat.entity.SeatHoldStatus.EXPIRED,
                   h.releasedAt = :now
             where h.concert.id = :concertId
               and h.activeSeat = :seatId
               and h.expiresAt <= :now
            """)
    int expireStaleForSeat(@Param("concertId") Long concertId,
                            @Param("seatId") Long seatId,
                            @Param("now") LocalDateTime now);

    /** 같은 회원의 만료 선점이 새 선점의 회원 유니크 제약을 막지 않게 정리한다. */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            update SeatHold h
               set h.status = com.ssafy.timo.domain.seat.entity.SeatHoldStatus.EXPIRED,
                   h.releasedAt = :now
             where h.concert.id = :concertId
               and h.activeMember = :memberId
               and h.expiresAt <= :now
            """)
    int expireStaleForMember(@Param("concertId") Long concertId,
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
