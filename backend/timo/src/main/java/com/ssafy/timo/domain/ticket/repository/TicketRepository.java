package com.ssafy.timo.domain.ticket.repository;

import com.ssafy.timo.domain.ticket.entity.Ticket;
import java.math.BigInteger;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface TicketRepository extends JpaRepository<Ticket, Long> {

    Optional<Ticket> findByTokenId(BigInteger tokenId);

    Optional<Ticket> findByReservationId(Long reservationId);

    /**
     * 여러 주문의 티켓 식별자를 한 번에 읽는다. 예매 목록이 응답에 {@code ticketId}를 실을 때 쓴다.
     *
     * <p><b>주문 하나씩 {@link #findByReservationId}를 부르면 페이지 크기만큼 쿼리가 나간다.</b>
     * {@code Reservation}은 티켓을 가리키지 않아(연관이 {@code Ticket -> Reservation} 단방향) 목록
     * 쿼리에 조인해 올 수도 없으므로, 페이지를 다 읽은 뒤 그 주문들의 티켓만 모아서 한 번 더 읽는다.
     *
     * <p>{@code Reservation}에 역방향 연관을 거는 쪽이 짧지만 그러면 안 된다 -
     * {@code @OneToOne(mappedBy)}는 LAZY가 듣지 않아(값이 {@code null}인지 알아야 프록시를 만들 수
     * 있다) 예매를 읽는 <b>모든</b> 경로에 티켓 조회가 따라붙는다. 이 프로젝트에는 그것을 풀어 줄
     * 바이트코드 인핸스먼트 설정이 없다.
     *
     * <p>엔티티가 아니라 식별자 두 개만 뽑는다. 필요한 것이 그뿐이라 티켓 행을 통째로 영속성
     * 컨텍스트에 올릴 이유가 없다.
     */
    @Query("""
            select t.reservation.id as reservationId,
                   t.id as ticketId
              from Ticket t
             where t.reservation.id in :reservationIds
            """)
    List<ReservationTicketId> findTicketIdsByReservationIds(
            @Param("reservationIds") Collection<Long> reservationIds);

    /** {@link #findTicketIdsByReservationIds}가 돌려주는 (주문, 티켓) 식별자 쌍. */
    interface ReservationTicketId {

        Long getReservationId();

        Long getTicketId();
    }
}
