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
     * 이 티켓의 가장 최근 체결.
     *
     * <p><b>"지금 이 티켓의 주인은 누구인가" 를 DB 로 답하는 유일한 근거다.</b> 티켓에는 소유자
     * 칼럼이 없고 {@code ticket.reservation.member} 는 <b>처음 예매한 사람</b>에서 영원히 멈춰 있다.
     * 그것만 보고 소유자를 판정하면 판 사람이 같은 티켓을 다시 등록할 수 있다.
     *
     * <p>그래서 현재 소유자는 이렇게 유도한다 — <b>최근 체결이 있으면 그 구매자, 없으면 예매자.</b>
     * 한 티켓이 여러 번 양도될 수 있으므로 가장 마지막 것을 본다.
     *
     * <p>{@code tradedAt} 이 같을 때를 대비해 {@code id} 를 덧붙인다. 같은 초에 두 건이 들어오면
     * 정렬이 흔들려 소유자가 요청마다 달라질 수 있다.
     *
     * <p>소유권의 정본은 온체인 {@code TicketNFT} 이고 이 판정은 그 미러다. 실제로 자산이 움직이는
     * 작업 앞에서는 {@code ownerOf(tokenId)} 로 다시 확인해야 한다.
     */
    Optional<TicketTrade> findFirstByTicketIdOrderByTradedAtDescIdDesc(Long ticketId);

    /**
     * 이미 체결된 매물인지 본다.
     *
     * <p>이중 체결을 <b>이 검사로 막지 않는다.</b> 확인과 INSERT 사이에 다른 요청이 끼어들 수 있어,
     * 실제 방어는 매물의 조건부 UPDATE 와 {@code uk_ticket_trade_listing} 제약이 한다.
     * 여기서는 조회·점검용으로만 쓴다.
     */
    boolean existsByListingId(Long listingId);
}
