package com.ssafy.timo.domain.transfer.repository;

import com.ssafy.timo.domain.transfer.dto.MyTradeRow;
import com.ssafy.timo.domain.transfer.entity.TicketTrade;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface TicketTradeRepository extends JpaRepository<TicketTrade, Long> {

    /**
     * 이 매물의 체결 건.
     *
     * <p>{@code listing_id} 에 유일 제약이 있어 결과는 최대 하나로 확정된다.
     */
    Optional<TicketTrade> findByListingId(Long listingId);

    /**
     * 거래 상세. 응답이 공연·공연장·구역을 쓰므로 매물을 거쳐 한 번에 읽는다(다대일만 fetch join).
     *
     * <p>요청자가 당사자인지는 여기서 거르지 않는다. 쿼리 조건에 넣으면 "없는 거래" 와 "남의 거래" 가 같은
     * 빈 결과가 되어 로그로도 구분할 수 없다. 서비스가 가르고 응답만 같은 404 로 낸다.
     */
    @Query("""
            select t
              from TicketTrade t
              join fetch t.listing l
              join fetch l.concert c
              join fetch c.venue
              join fetch l.section
             where t.id = :tradeId
            """)
    Optional<TicketTrade> findDetailById(@Param("tradeId") Long tradeId);

    /**
     * 내 거래 내역. 판매({@code ticket_listing})와 구매({@code ticket_trade})를 한 목록으로 합친다.
     *
     * <p><b>네이티브 SQL 인 이유는 JPQL 에 {@code union} 이 없기 때문이다.</b> 두 테이블을 자바에서
     * 각각 읽어 합치면 페이지 경계가 어긋난다 — 5번째 페이지를 만들려고 양쪽에서 얼마씩 읽어야
     * 하는지 미리 알 수 없어, 결국 필요 이상으로 읽고 잘라내게 된다. 정렬과 페이징은 DB 가 한다.
     *
     * <p>{@code SALE} 은 {@code seller_member_id}, {@code PURCHASE} 는 {@code buyer_member_id} 기준이다.
     * 내가 올린 매물이 팔리면 {@code SALE} 항목의 상태가 {@code SOLD} 로 바뀔 뿐, 별도의
     * {@code PURCHASE} 항목이 생기지 않는다 — 그건 산 사람의 내역이다.
     *
     * <p>금액이 두 갈래인 데 주의한다. 판매는 매물의 등록가, 구매는 <b>체결가</b>다. 등록가는 불변이라
     * 지금은 같은 값이지만, 정산의 근거는 거래에 박힌 금액이어야 한다.
     *
     * <p>정렬은 {@code occurredAt} 내림차순이고 동점은 {@code listingId} 내림차순으로 고정한다.
     * 같은 시각에 두 건이 들어오면 순서가 흔들려 페이지를 넘길 때 항목이 겹치거나 사라진다.
     *
     * <p><b>{@code Pageable} 의 정렬은 비워서 넘긴다.</b> 정렬이 쿼리 안에 있고, 넘기면 뒤에 덧붙어
     * {@code union} 결과에 대한 정렬이 깨진다.
     */
    @Query(value = """
            select 'SALE'            as tradeType,
                   null              as tradeId,
                   l.listing_id      as listingId,
                   l.status          as status,
                   c.concert_id      as concertId,
                   c.title           as concertTitle,
                   c.poster_image_key as posterImageKey,
                   c.start_date      as startDate,
                   v.venue_name      as venueName,
                   s.name            as sectionName,
                   s.grade           as grade,
                   l.seat_no         as seatNo,
                   l.seat_col        as seatCol,
                   l.price           as price,
                   l.face_value      as faceValue,
                   l.listed_at       as occurredAt
              from ticket_listing l
              join concert c on c.concert_id = l.concert_id
              join venue v   on v.venue_id   = c.venue_id
              join section s on s.section_id = l.section_id
             where l.seller_member_id = :memberId
            union all
            select 'PURCHASE',
                   t.trade_id,
                   l2.listing_id,
                   t.status,
                   c2.concert_id,
                   c2.title,
                   c2.poster_image_key,
                   c2.start_date,
                   v2.venue_name,
                   s2.name,
                   s2.grade,
                   l2.seat_no,
                   l2.seat_col,
                   t.price,
                   l2.face_value,
                   t.traded_at
              from ticket_trade t
              join ticket_listing l2 on l2.listing_id = t.listing_id
              join concert c2 on c2.concert_id = l2.concert_id
              join venue v2   on v2.venue_id   = c2.venue_id
              join section s2 on s2.section_id = l2.section_id
             where t.buyer_member_id = :memberId
             order by occurredAt desc, listingId desc
            """,
            countQuery = """
            select (select count(*) from ticket_listing l where l.seller_member_id = :memberId)
                 + (select count(*) from ticket_trade t where t.buyer_member_id = :memberId)
            """,
            nativeQuery = true)
    Page<MyTradeRow> findMyTrades(@Param("memberId") Long memberId, Pageable pageable);


    /**
     * 이미 체결된 매물인지 본다.
     *
     * <p>이중 체결을 <b>이 검사로 막지 않는다.</b> 확인과 INSERT 사이에 다른 요청이 끼어들 수 있어,
     * 실제 방어는 매물의 조건부 UPDATE 와 {@code uk_ticket_trade_listing} 제약이 한다.
     * 여기서는 조회·점검용으로만 쓴다.
     */
    boolean existsByListingId(Long listingId);

    /**
     * 한 번이라도 양도된 티켓인지 본다. 예매 취소가 이 값으로 막힌다.
     *
     * <p>현재 소유자가 누구든 상관없이 이력 유무만 묻는다. 되사기(A→B→A)로 원 예매자에게 돌아온
     * 티켓도 {@code true} 다 — 그 사이 오간 양도 대금과 예매 환불이 섞이므로 원 주문으로 되돌리지 않는다.
     */
    boolean existsByTicketId(Long ticketId);
}
