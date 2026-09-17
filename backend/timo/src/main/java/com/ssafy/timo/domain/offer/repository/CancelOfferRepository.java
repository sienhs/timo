package com.ssafy.timo.domain.offer.repository;

import com.ssafy.timo.domain.offer.entity.CancelOffer;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface CancelOfferRepository extends JpaRepository<CancelOffer, Long> {

    /** 이 좌석에 지금 열려 있는 기회. 좌석 선점이 회수 좌석의 잠금을 풀지 말지 여기서 판정한다. */
    @Query("""
            select o from CancelOffer o
             where o.concert.id = :concertId
               and o.seat.id = :seatId
               and o.status = com.ssafy.timo.domain.offer.entity.OfferStatus.OFFERED
               and o.expiresAt > :now
            """)
    Optional<CancelOffer> findActiveOfSeat(@Param("concertId") Long concertId,
                                          @Param("seatId") Long seatId,
                                          @Param("now") LocalDateTime now);

    /** 내게 열려 있는 기회들. 카드에 공연·공연장·구역이 실리므로 다대일만 함께 읽는다. */
    @Query("""
            select o from CancelOffer o
              join fetch o.concert c
              join fetch c.venue
              join fetch o.seat s
              join fetch s.section
             where o.member.id = :memberId
               and o.status = com.ssafy.timo.domain.offer.entity.OfferStatus.OFFERED
               and o.expiresAt > :now
             order by o.expiresAt asc, o.id asc
            """)
    List<CancelOffer> findActiveOfMember(@Param("memberId") Long memberId, @Param("now") LocalDateTime now);

    /** 추첨 제외용. 이 공연에서 이미 기회를 들고 있는 회원은 한 번 더 뽑지 않는다. */
    @Query("""
            select o.member.id from CancelOffer o
             where o.concert.id = :concertId
               and o.status = com.ssafy.timo.domain.offer.entity.OfferStatus.OFFERED
               and o.expiresAt > :now
            """)
    List<Long> findActiveMemberIdsByConcertId(@Param("concertId") Long concertId, @Param("now") LocalDateTime now);

    /**
     * 기한이 지난 채 {@code OFFERED} 로 남은 행을 {@code EXPIRED} 로 닫는다.
     *
     * <p>스케줄러가 없어 만료는 이렇게 뒤늦게 적는다. 같은 좌석에 새 기회를 열기 직전에 불러야
     * {@code uk_offer_seat_active} 가 비워진다. 조회는 어차피 {@code expires_at} 을 보므로 이 갱신이
     * 늦어도 판정은 틀리지 않는다.
     *
     * <p><b>영속성 컨텍스트를 비우지 않는다.</b> 예매 취소 트랜잭션 안에서 불리는데, 비우면 취소가 응답을
     * 만들 때 쓰는 주문과 티켓이 준영속이 되어 지연 로딩이 터진다. 바뀐 행을 같은 트랜잭션에서 다시
     * 읽는 곳이 없어 비울 이유도 없다.
     */
    @Modifying(flushAutomatically = true)
    @Query("""
            update CancelOffer o
               set o.status = com.ssafy.timo.domain.offer.entity.OfferStatus.EXPIRED
             where o.concert.id = :concertId
               and o.seat.id = :seatId
               and o.status = com.ssafy.timo.domain.offer.entity.OfferStatus.OFFERED
               and o.expiresAt <= :now
            """)
    int expireStaleOfSeat(@Param("concertId") Long concertId,
                          @Param("seatId") Long seatId,
                          @Param("now") LocalDateTime now);

    /**
     * 당첨자가 결제했다. 조건에 기한을 넣어 <b>전이의 결과로</b> 판정한다 — 기한 직후 결제가
     * 들어오면 영향 행이 0 이고, 그 결제는 기회가 아니라 일반 예매로 성립한 것이다.
     *
     * <p>영속성 컨텍스트를 비우지 않는다. 예매 생성 트랜잭션 안에서 불리므로 {@link #expireStaleOfSeat}
     * 와 같은 사정이다.
     */
    @Modifying(flushAutomatically = true)
    @Query("""
            update CancelOffer o
               set o.status = com.ssafy.timo.domain.offer.entity.OfferStatus.ACCEPTED,
                   o.reservationId = :reservationId
             where o.concert.id = :concertId
               and o.seat.id = :seatId
               and o.member.id = :memberId
               and o.status = com.ssafy.timo.domain.offer.entity.OfferStatus.OFFERED
               and o.expiresAt > :now
            """)
    int markAcceptedIfActive(@Param("concertId") Long concertId,
                             @Param("seatId") Long seatId,
                             @Param("memberId") Long memberId,
                             @Param("reservationId") Long reservationId,
                             @Param("now") LocalDateTime now);
}
