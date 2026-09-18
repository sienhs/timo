package com.ssafy.timo.domain.goods.repository;

import com.ssafy.timo.domain.goods.dto.CollectibleConcertRow;
import com.ssafy.timo.domain.goods.entity.Goods;
import com.ssafy.timo.domain.ticket.repository.TicketOwnershipSql;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

/**
 * 굿즈 저장소. 티켓 소유 판정과 소장품 공연 목록처럼 <b>티켓·거래 테이블을 읽는 쿼리도 여기 둔다.</b>
 *
 * <p>티켓 도메인의 {@code TicketRepository} 에 메서드를 보태지 않는 이유는 남의 도메인 파일을
 * 굿즈 사정으로 고치지 않기 위해서다. 네이티브 SQL 은 어느 리포지토리에 있든 어느 테이블이든 읽을
 * 수 있으므로 굿즈가 필요한 쿼리는 굿즈 패키지가 가진다.
 *
 * <p>"현재 소유자" 판정은 옮겨 적지 않고 {@link TicketOwnershipSql#CURRENT_OWNER} 를 끌어다 쓴다.
 * 예전에는 티켓 쪽 규칙을 글자 그대로 복사해 두고 "그쪽이 바뀌면 여기도 같이 바꾼다" 고 적어
 * 두었는데, 네이티브라 기동 시점에 검증되지 않아 한쪽만 고쳐도 아무 데서도 티가 나지 않았다.
 * 조각을 공유하면 갈릴 수가 없고, 쓰는 쪽이 조건을 덧붙여 갈리는 것은
 * {@code GoodsApiIntegrationTest} 의 교차 검증이 잡는다.
 */
@Repository
public interface GoodsRepository extends JpaRepository<Goods, Long> {

    @Query("select g from Goods g where g.ticket.id = :ticketId")
    Optional<Goods> findByTicketId(@Param("ticketId") Long ticketId);

    /** 남의 굿즈는 빈 결과다. 존재 여부를 응답으로 구분하지 않는다. */
    @Query("select g from Goods g where g.id = :goodsId and g.member.id = :memberId")
    Optional<Goods> findByIdAndMemberId(@Param("goodsId") Long goodsId, @Param("memberId") Long memberId);

    /** 멱등 키로 찾는다. 같은 회원이 같은 키를 다른 티켓에 다시 쓴 경우를 가릴 때 쓴다. */
    @Query("select g from Goods g where g.member.id = :memberId and g.clientGoodsId = :clientGoodsId")
    Optional<Goods> findByMemberIdAndClientGoodsId(@Param("memberId") Long memberId,
                                                   @Param("clientGoodsId") String clientGoodsId);

    /**
     * 내 굿즈 목록, 최신 순. 정렬은 문장 안에 고정돼 있어 {@link Pageable} 은 페이지 번호·크기만 쓴다.
     * {@code created_at} 이 같은 초에 여럿이면 id 로 순서를 못 박는다.
     */
    @Query(value = """
            select g from Goods g
             where g.member.id = :memberId
             order by g.createdAt desc, g.id desc
            """,
            countQuery = "select count(g) from Goods g where g.member.id = :memberId")
    Page<Goods> findMyGoods(@Param("memberId") Long memberId, Pageable pageable);

    /**
     * 이 회원이 <b>지금</b> 이 티켓을 가졌으면 1, 아니면 0.
     *
     * <p>티켓이 없어도 0 이다. 서비스는 둘을 구분하지 않고 같은 404 로 답한다.
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

    /**
     * 굿즈를 만들 수 있는 공연 목록 — 내가 지금 가진 티켓 중 입장 완료({@code USED})한 것.
     *
     * <p>이미 만든 굿즈의 id 를 {@code left join goods} 로 <b>같은 문장에서</b> 가져온다. 티켓마다
     * 굿즈를 따로 조회하면 티켓 수만큼 쿼리가 나간다. 아티스트도 같은 이유로 서브쿼리에서
     * {@code group_concat} 으로 한 줄로 합친다.
     *
     * <p>영상 URL 은 싣지 않는다. {@code concert} 에 영상 컬럼이 없다.
     */
    @Query(value = """
            select t.ticket_id        as ticketId,
                   c.concert_id       as concertId,
                   c.title            as title,
                   (select group_concat(a.artist_name order by ca.concert_artist_id separator ', ')
                      from concert_artist ca
                      join artist a on a.artist_id = ca.artist_id
                     where ca.concert_id = c.concert_id) as artist,
                   c.start_date       as startDate,
                   v.venue_name       as venue,
                   c.poster_image_key as posterImageKey,
                   g.goods_id         as goodsId
              from (
            """ + TicketOwnershipSql.CURRENT_OWNER + """
                   ) owned
              join ticket t      on t.ticket_id = owned.ticket_id
              join reservation r on r.reservation_id = t.reservation_id
              join concert c     on c.concert_id = r.concert_id
              join venue v       on v.venue_id = c.venue_id
              -- 굿즈는 만든 사람 것이다. 소유자 조건을 빼면 양도된 티켓에서 전 소유자가 만든
              -- goods_id 가 새 소유자 행에 실려, 앱이 "이미 만듦" 으로 그린 뒤 상세를 부르면
              -- findByIdAndMemberId 가 남의 굿즈를 걸러 404 가 된다.
              left join goods g  on g.ticket_id = t.ticket_id
                                and g.member_id = :memberId
             where t.status = 'USED'
             order by owned.acquired_at desc, t.ticket_id desc
            """,
            nativeQuery = true)
    List<CollectibleConcertRow> findCollectibleConcerts(@Param("memberId") Long memberId);
}
