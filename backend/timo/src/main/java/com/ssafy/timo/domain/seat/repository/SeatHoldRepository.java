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
     * 만료된 선점을 한꺼번에 {@code EXPIRED} 로 정리한다.
     *
     * <p><b>새 선점을 넣기 전에 반드시 먼저 불러야 한다.</b> 유니크 제약({@code uk_hold_seat})의 재료인
     * 생성 칼럼은 {@code status='HELD'} 인 동안 값을 갖는다. 만료됐지만 아직 {@code HELD} 로 남아 있는
     * 행이 있으면, 그 자리를 새로 잡으려는 요청이 <b>이미 풀린 선점 때문에</b> 유니크 충돌로 거절된다.
     *
     * <p>조회 시점 판정(만료된 선점을 읽을 때만 무시)만으로는 이 문제를 못 푼다. 유니크 인덱스는
     * 애플리케이션의 판정을 모르기 때문이다.
     *
     * <p>{@code flushAutomatically} 로 앞선 변경을 먼저 내보내고, {@code clearAutomatically} 로
     * 영속성 컨텍스트에 남은 옛 상태를 비운다. 비우지 않으면 방금 DB 에서 만료시킨 행을 엔티티로 다시
     * 읽을 때 {@code HELD} 로 보인다.
     *
     * @return 정리된 행 수
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            update SeatHold h
               set h.status = com.ssafy.timo.domain.seat.entity.SeatHoldStatus.EXPIRED,
                   h.releasedAt = :now
             where h.status = com.ssafy.timo.domain.seat.entity.SeatHoldStatus.HELD
               and h.expiresAt <= :now
            """)
    int expireAllStale(@Param("now") LocalDateTime now);

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
