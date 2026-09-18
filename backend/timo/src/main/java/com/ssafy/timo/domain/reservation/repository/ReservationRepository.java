package com.ssafy.timo.domain.reservation.repository;

import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.reservation.entity.ReservationStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
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
     * 이 공연에서 이 좌석이 취소 뒤 해제를 기다리는 중인지.
     *
     * <p>취소된 주문은 좌석을 놓아 주지만 곧바로는 아니다. 해제 시각까지는 선점처럼 잠긴다.
     * 좌석 조회가 같은 조건을 쓰므로({@code SeatRepository}) 둘이 갈리면 화면과 선점이 어긋난다.
     */
    @Query("""
            select count(r) > 0
            from Reservation r
            where r.concert.id = :concertId
              and r.seat.id = :seatId
              and r.status = com.ssafy.timo.domain.reservation.entity.ReservationStatus.CANCELLED
              and r.seatReleaseAt > :now
            """)
    boolean existsSeatAwaitingRelease(@Param("concertId") Long concertId,
                                      @Param("seatId") Long seatId,
                                      @Param("now") LocalDateTime now);

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

    /** 내 주문 목록. 카드에 필요한 연관을 함께 읽는다 - status가 null이면 전체를 본다. */
    @Query(value = """
            select r from Reservation r
            join fetch r.concert c
            join fetch c.venue
            join fetch r.seat s
            join fetch s.section
            where r.member.id = :memberId
              and (:status is null or r.status = :status)
            """,
            countQuery = """
            select count(r) from Reservation r
            where r.member.id = :memberId
              and (:status is null or r.status = :status)
            """)
    Page<Reservation> findPageByMemberId(@Param("memberId") Long memberId, @Param("status") ReservationStatus status, Pageable pageable);
}
