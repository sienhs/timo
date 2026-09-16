package com.ssafy.timo.domain.reservation.repository;

import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.reservation.entity.ReservationStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
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
     * 이 공연에서 이 좌석이 취소된 적이 있는지("회수됨").
     *
     * <p>취소는 자리를 곧바로 예매 가능으로 되돌리지 않는다. 재오픈 절차(스토리 35)가 생기기 전에는
     * 이 판정이 영구적이라, 취소된 적이 있으면 선점도 막는다 — {@code SeatWithStatus} 가 조회에서
     * 회수됨으로 보여주는 것과 같은 규칙을 여기서도 지켜야, 화면엔 안 보이는 자리를 API 로 직접
     * 잡는 통로가 남지 않는다.
     */
    @Query("""
            select count(r) > 0
            from Reservation r
            where r.concert.id = :concertId
              and r.seat.id = :seatId
              and r.status = com.ssafy.timo.domain.reservation.entity.ReservationStatus.CANCELLED
            """)
    boolean existsRevokedSeat(@Param("concertId") Long concertId, @Param("seatId") Long seatId);

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
