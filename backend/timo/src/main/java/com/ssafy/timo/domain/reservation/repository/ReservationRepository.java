package com.ssafy.timo.domain.reservation.repository;

import com.ssafy.timo.domain.reservation.entity.Reservation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface ReservationRepository extends JpaRepository<Reservation, Long> {

    /**
     * 이 공연에서 이 좌석이 이미 팔렸는지.
     *
     * <p>선점 유니크({@code uk_hold_seat})는 선점끼리만 막는다. 팔린 자리를 다시 선점하려는 요청은
     * 거기 걸리지 않으므로 이 검사가 따로 필요하다.
     */
    @Query("""
            select count(r) > 0
            from Reservation r
            where r.concert.id = :concertId
              and r.seat.id = :seatId
              and r.status = com.ssafy.timo.domain.reservation.entity.ReservationStatus.PAID
            """)
    boolean existsPaidSeat(@Param("concertId") Long concertId, @Param("seatId") Long seatId);

    /**
     * 이 공연에서 이 회원의 유효한 주문. "한 계정 한 공연 1매" 판정에 쓴다.
     *
     * <p>{@code uk_rsv_member} 가 최종 방어선이므로 최대 한 건이다.
     */
    @Query("""
            select r
            from Reservation r
            where r.concert.id = :concertId
              and r.member.id = :memberId
              and r.status = com.ssafy.timo.domain.reservation.entity.ReservationStatus.PAID
            """)
    Optional<Reservation> findPaidOfMember(@Param("concertId") Long concertId,
                                           @Param("memberId") Long memberId);
}
