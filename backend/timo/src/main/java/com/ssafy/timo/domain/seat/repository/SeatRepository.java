package com.ssafy.timo.domain.seat.repository;

import com.ssafy.timo.domain.seat.entity.Seat;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;

/**
 * 좌석 조회.
 *
 * <p>좌석 상태를 묻는 메서드는 <b>전부 공연 id 를 받는다.</b> 좌석은 공연장 마스터 데이터라 공연을
 * 빼고는 상태가 정해지지 않기 때문이다. 공연을 안 받는 메서드는 위치·개수처럼 공연과 무관한 것뿐이다.
 *
 * <p>{@code SELECT ... FOR UPDATE} 는 두지 않는다. 좌석 행은 모든 공연이 공유하므로 거기 잠금을 걸면
 * 서로 다른 공연의 선점 요청이 같은 행 앞에 줄을 선다. 동시성 판정은 {@code seat_hold} ·
 * {@code reservation} 의 유니크 제약이 맡는다.
 */
@Repository
public interface SeatRepository extends JpaRepository<Seat, Long> {

    long countBySectionId(Long sectionId);

    /** 한 구역의 좌석을 배치도 순서로 읽는다. 상태는 보지 않으므로 공연과 무관하다. */
    List<Seat> findAllBySectionIdOrderBySeatNoAscSeatColAsc(Long sectionId);

    /**
     * 한 구역의 좌석을, <b>이 공연에서 본 상태와 함께</b> 배치도 순서로 읽는다.
     *
     * <p>선점과 주문을 각각 LEFT JOIN 한다. 조인 조건에 {@code concert_id} 가 들어 있으므로 다른 공연의
     * 선점·주문은 아예 붙지 않는다 — 9/20 공연에서 팔린 자리가 9/21 좌석표에 팔린 것으로 보이던
     * 문제가 여기서 끊긴다.
     *
     * <p>선점 쪽 조인에 {@code expiresAt > :now} 를 건다. 만료된 선점은 아직 {@code HELD} 로 남아
     * 있어도 자리를 붙들지 않으므로 좌석표에서는 빈 자리로 보여야 한다.
     *
     * <p>취소표 구매 기회는 스칼라 서브쿼리로 본다. 열린 기회는 좌석당 하나뿐이지만
     * ({@code uk_offer_seat_active}) 집계로 받아 두면 제약이 흔들려도 행이 중복되지 않는다.
     */
    @Query("""
            select new com.ssafy.timo.domain.seat.repository.SeatWithStatus(
                       s.id, s.seatNo, s.seatCol, h.id, r.id,
                       (select max(o.id) from CancelOffer o
                        where o.seat = s
                          and o.concert.id = :concertId
                          and o.status = com.ssafy.timo.domain.offer.entity.OfferStatus.OFFERED
                          and o.expiresAt > :now))
            from Seat s
            left join SeatHold h
                   on h.seat = s
                  and h.concert.id = :concertId
                  and h.status = com.ssafy.timo.domain.seat.entity.SeatHoldStatus.HELD
                  and h.expiresAt > :now
            left join Reservation r
                   on r.seat = s
                  and r.concert.id = :concertId
                  and r.status = com.ssafy.timo.domain.reservation.entity.ReservationStatus.PAID
            where s.section.id = :sectionId
            order by s.seatNo asc, s.seatCol asc
            """)
    List<SeatWithStatus> findSeatsWithStatus(@Param("concertId") Long concertId,
                                             @Param("sectionId") Long sectionId,
                                             @Param("now") LocalDateTime now);

    /**
     * 여러 구역의 예매 가능 좌석 수를 이 공연 기준으로 한 번에 센다.
     *
     * <p>조인 대신 {@code not exists} 를 쓴다. 조인으로 세면 한 좌석에 선점·주문 행이 여럿 붙었을 때
     * 좌석이 중복으로 세어질 수 있다. 유니크 제약상 그럴 일이 없어야 하지만, 집계가 제약의 정확성에
     * 기대지 않는 편이 안전하다.
     *
     * <p>예매 가능 좌석이 하나도 없는 구역은 결과에 포함되지 않는다. 읽는 쪽에서 0 으로 채운다 —
     * 빠뜨리면 매진 구역이 목록에서 사라진다.
     *
     * <p>취소표 구매 기회가 열린 자리도 뺀다. 당첨자 한 사람 몫이라 잔여석이 아니다. 기회가 끝나면
     * 조건에서 빠져 저절로 잔여석으로 돌아온다.
     */
    @Query("""
            select new com.ssafy.timo.domain.seat.repository.SectionAvailableCount(
                       s.section.id, count(s))
            from Seat s
            where s.section.id in :sectionIds
              and not exists (
                    select 1 from SeatHold h
                    where h.seat = s
                      and h.concert.id = :concertId
                      and h.status = com.ssafy.timo.domain.seat.entity.SeatHoldStatus.HELD
                      and h.expiresAt > :now)
              and not exists (
                    select 1 from Reservation r
                    where r.seat = s
                      and r.concert.id = :concertId
                      and r.status = com.ssafy.timo.domain.reservation.entity.ReservationStatus.PAID)
              and not exists (
                    select 1 from CancelOffer o
                    where o.seat = s
                      and o.concert.id = :concertId
                      and o.status = com.ssafy.timo.domain.offer.entity.OfferStatus.OFFERED
                      and o.expiresAt > :now)
            group by s.section.id
            """)
    List<SectionAvailableCount> countAvailableGroupedBySection(
            @Param("concertId") Long concertId,
            @Param("sectionIds") Collection<Long> sectionIds,
            @Param("now") LocalDateTime now);

    /**
     * 이 공연의 남은 좌석 수. 공연이 열리는 공연장의 전체 좌석에서 선점·판매분을 뺀다.
     *
     * <p>공연장을 파라미터로 받지 않고 공연에서 찾아 들어간다. 호출하는 쪽이 공연장을 따로 조회해
     * 넘기게 하면, 공연과 다른 공연장을 넘기는 실수가 조용히 통과한다.
     */
    @Query("""
            select count(s)
            from Seat s
            where s.section.venue.id = (select c.venue.id from Concert c where c.id = :concertId)
              and not exists (
                    select 1 from SeatHold h
                    where h.seat = s
                      and h.concert.id = :concertId
                      and h.status = com.ssafy.timo.domain.seat.entity.SeatHoldStatus.HELD
                      and h.expiresAt > :now)
              and not exists (
                    select 1 from Reservation r
                    where r.seat = s
                      and r.concert.id = :concertId
                      and r.status = com.ssafy.timo.domain.reservation.entity.ReservationStatus.PAID)
              and not exists (
                    select 1 from CancelOffer o
                    where o.seat = s
                      and o.concert.id = :concertId
                      and o.status = com.ssafy.timo.domain.offer.entity.OfferStatus.OFFERED
                      and o.expiresAt > :now)
            """)
    long countAvailable(@Param("concertId") Long concertId, @Param("now") LocalDateTime now);
}
