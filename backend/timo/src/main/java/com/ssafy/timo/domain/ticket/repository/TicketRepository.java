package com.ssafy.timo.domain.ticket.repository;

import com.ssafy.timo.domain.ticket.dto.MyTicketRow;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import java.math.BigInteger;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
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

    /**
     * 내가 지금 가진 티켓 목록.
     *
     * <p>{@code reservation.member} 는 <b>처음 예매한 사람</b>에서 멈춰 있어, 그것만 보면 판 사람에게
     * 판 티켓이 남고 산 사람에게는 산 티켓이 안 보인다. 그래서 두 갈래를 합친다 — 내가 예매했고
     * <b>거래된 적 없는</b> 티켓과, 그 티켓의 <b>마지막 거래</b>에서 내가 산 티켓이다. 되산 경우
     * ({@code A->B->A})는 앞 갈래에서 빠지고 뒤 갈래가 잡는다. 마지막을 {@code MAX(trade_id)} 로
     * 고르는 것은 재양도({@code A->B->C}) 때문이고, 같은 초에 두 건이 와도 순서가 안 흔들린다.
     *
     * <p>두 갈래 모두 인덱스에서 출발한다({@code ix_rsv_member}, {@code idx_trade_buyer}).
     * {@code where coalesce(마지막구매자, 예매자) = :memberId} 로 쓰면 유도값이라 인덱스를 못 탄다.
     * 네이티브라 기동 시점에 검증되지 않으므로 통합 테스트가 이 쿼리를 지킨다.
     */
    @Query(value = """
            select t.ticket_id        as ticketId,
                   r.reservation_id   as reservationId,
                   c.concert_id       as concertId,
                   c.title            as concertTitle,
                   c.poster_image_key as posterImageKey,
                   c.start_date       as startDate,
                   v.venue_name       as venueName,
                   s.name             as sectionName,
                   st.seat_no         as seatNo,
                   st.seat_col        as seatCol,
                   s.price            as facePrice,
                   t.status           as ticketStatus,
                   owned.acquired_by  as acquiredBy,
                   owned.acquired_at  as acquiredAt,
                   exists (select 1
                             from ticket_listing l
                            where l.ticket_id = t.ticket_id
                              and l.status = 'LISTED') as listed
              from (
            """ + TicketOwnershipSql.CURRENT_OWNER + """
                   ) owned
              join ticket t      on t.ticket_id = owned.ticket_id
              join reservation r on r.reservation_id = t.reservation_id
              join concert c     on c.concert_id = r.concert_id
              join venue v       on v.venue_id = c.venue_id
              join seat st       on st.seat_id = r.seat_id
              join section s     on s.section_id = st.section_id
             order by owned.acquired_at desc, t.ticket_id desc
            """,
            countQuery = """
            select count(*) from (
            """ + TicketOwnershipSql.CURRENT_OWNER + """
                   ) owned
            """,
            nativeQuery = true)
    Page<MyTicketRow> findMyTickets(@Param("memberId") Long memberId, Pageable pageable);

    /**
     * 이 회원이 <b>지금</b> 이 티켓을 가졌으면 1, 아니면 0. {@link com.ssafy.timo.domain.goods.repository.GoodsRepository#countCurrentOwnership}과 같은 조각.
     *
     * <p>{@code reservation.member}(최초 예매자)가 아니라 이걸로 판정해야, 양도로 주인이 바뀐 뒤에도
     * 판 사람이 아니라 산 사람이 입장 QR을 받는다.
     */
    @Query(value = """
            select count(*)
              from (
            """ + TicketOwnershipSql.CURRENT_OWNER + """
                   ) owned
             where owned.ticket_id = :ticketId
            """,
            nativeQuery = true)
    long countCurrentOwnership(@Param("memberId") Long memberId, @Param("ticketId") Long ticketId);

    /** {@link #findTicketIdsByReservationIds}가 돌려주는 (주문, 티켓) 식별자 쌍. */
    interface ReservationTicketId {

        Long getReservationId();

        Long getTicketId();
    }

    /**
     * 입장 처리. <b>중복 입장을 막는 곳이 여기다.</b>
     *
     * <p>읽고 나서 판단하고 쓰면 게이트 두 대가 같은 티켓을 동시에 스캔했을 때 둘 다
     * {@code OWNED}를 읽고 둘 다 통과한다. 조건을 UPDATE 문 안에 넣으면 DB가 행 잠금으로
     * 직렬화해 주므로, 몇 대가 동시에 찍든 1을 받는 쪽은 하나뿐이다.
     *
     * <p>덕분에 QR 문자열마다 사용 여부를 따로 기억할 필요가 없다. 캡처해 둔 예전 QR을 들이밀어도
     * 그 티켓은 이미 {@code USED}라 여기서 0이 나온다. 별도 nonce 테이블이나 Redis가 없는 이유다.
     *
     * <p>벌크 연산이라 {@code updatedAt} 감사 필드는 갱신되지 않는다. 입장 시각이 필요해지면
     * 그때 컬럼을 따로 두고 이 UPDATE에서 함께 채운다.
     *
     * @return 1이면 이번 호출이 입장시킨 것이고, 0이면 이미 입장했거나 정상 소유 상태가 아니다
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("""
            update Ticket t
               set t.status = com.ssafy.timo.domain.ticket.entity.TicketStatus.USED
             where t.id = :ticketId
               and t.status = com.ssafy.timo.domain.ticket.entity.TicketStatus.OWNED
            """)
    int markUsedIfOwned(@Param("ticketId") Long ticketId);

    /**
     * 이 공연의 티켓을 지금 들고 있는 회원 id. 취소표 추첨에서 뺄 사람이다.
     *
     * <p>판정은 {@link #findMyTickets} 와 같은 두 갈래다 — 거래된 적 없는 {@code PAID} 주문의 예매자, 그리고
     * 마지막 거래의 구매자. 판 사람은 주문이 {@code PAID} 로 남아 첫 갈래에 잡히는데, 예매의 1인 1매도 그
     * 주문을 보므로 뽑아 봐야 결제가 막힌다. 산 사람은 주문이 없어 둘째 갈래로만 잡힌다.
     */
    @Query(value = """
            select r1.member_id
              from ticket t1
              join reservation r1 on r1.reservation_id = t1.reservation_id
             where r1.concert_id = :concertId
               and r1.status = 'PAID'
               and not exists (select 1 from ticket_trade tt where tt.ticket_id = t1.ticket_id)
            union
            select tt2.buyer_member_id
              from ticket_trade tt2
              join ticket t2      on t2.ticket_id = tt2.ticket_id
              join reservation r2 on r2.reservation_id = t2.reservation_id
             where r2.concert_id = :concertId
               and tt2.trade_id = (select max(x.trade_id) from ticket_trade x
                                    where x.ticket_id = tt2.ticket_id)
            """, nativeQuery = true)
    List<Long> findHoldingMemberIdsByConcertId(@Param("concertId") Long concertId);
}
