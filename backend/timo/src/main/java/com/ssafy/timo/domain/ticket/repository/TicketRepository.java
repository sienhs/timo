package com.ssafy.timo.domain.ticket.repository;

import com.ssafy.timo.domain.ticket.dto.MyTicketRow;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import java.math.BigInteger;
import java.time.LocalDateTime;
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

    /** 현재 귀속 회원의 티켓. 취득 정보도 Ticket에 저장된 값을 사용한다. */
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
                   t.acquired_by  as acquiredBy,
                   t.acquired_at  as acquiredAt,
                   exists (select 1
                             from ticket_listing l
                            where l.ticket_id = t.ticket_id
                              and l.status = 'LISTED') as listed
              from ticket t
              join reservation r on r.reservation_id = t.reservation_id
              join concert c     on c.concert_id = r.concert_id
              join venue v       on v.venue_id = c.venue_id
              join seat st       on st.seat_id = r.seat_id
              join section s     on s.section_id = st.section_id
             where t.owner_member_id = :memberId
             order by t.acquired_at desc, t.ticket_id desc
            """,
            countQuery = """
            select count(*) from ticket where owner_member_id = :memberId
            """,
            nativeQuery = true)
    Page<MyTicketRow> findMyTickets(@Param("memberId") Long memberId, Pageable pageable);

    Optional<Ticket> findByIdAndOwnerMemberId(Long ticketId, Long memberId);

    boolean existsByIdAndOwnerMemberId(Long ticketId, Long memberId);

    /** 기존 구매 트랜잭션 안에서만 호출한다. 소유자와 발행 상태를 함께 갱신한다. */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("""
            update Ticket t
               set t.ownerMemberId = :buyerId,
                   t.acquiredBy = com.ssafy.timo.domain.ticket.dto.TicketAcquisition.TRANSFER,
                   t.acquiredAt = :acquiredAt,
                   t.status = com.ssafy.timo.domain.ticket.entity.TicketStatus.OWNED,
                   t.updatedAt = :acquiredAt
             where t.id = :ticketId
               and t.ownerMemberId = :sellerId
               and t.status = com.ssafy.timo.domain.ticket.entity.TicketStatus.LISTED
            """)
    int transferOwnershipIfListed(@Param("ticketId") Long ticketId,
                                  @Param("sellerId") Long sellerId,
                                  @Param("buyerId") Long buyerId,
                                  @Param("acquiredAt") LocalDateTime acquiredAt);

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
     * 알림의 기존 포함 조건을 유지한다: 거래 이력이 있거나 PAID 주문인 티켓.
     * 소유자 선택은 거래 상태·순서와 관계없이 Ticket 한 곳을 따른다.
     * 티켓 상태를 추가로 제한하지 않으며 회원은 공연 안에서 중복되지 않는다.
     */
    @Query(value = """
            select distinct t.owner_member_id
              from ticket t
              join reservation r on r.reservation_id = t.reservation_id
             where r.concert_id = :concertId
               and (r.status = 'PAID'
                    or exists (select 1 from ticket_trade tt where tt.ticket_id = t.ticket_id))
            """, nativeQuery = true)
    List<Long> findHoldingMemberIdsByConcertId(@Param("concertId") Long concertId);
}
