package com.ssafy.timo.domain.transfer.repository;

import com.ssafy.timo.domain.transfer.dto.MarketConcertRow;
import com.ssafy.timo.domain.transfer.entity.ListingStatus;
import com.ssafy.timo.domain.transfer.entity.TicketListing;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.Optional;

@Repository
public interface TicketListingRepository extends JpaRepository<TicketListing, Long> {

    /**
     * 양도 매물이 올라와 있는 공연 목록. 공연마다 매물 수와 최저가만 모은다.
     *
     * <p>집계는 {@code group by} 한 번이다. 공연을 먼저 뽑고 공연마다 개수를 세면 N+1 이 된다.
     *
     * <p>{@code LISTED} 매물이 하나도 없는 공연은 애초에 결과에 나오지 않는다 —
     * {@code TicketListing} 에서 출발해 공연으로 조인하기 때문이다. 매물이 0 인 행을 내보내면
     * 사용자가 들어가 봐야 빈 화면이다.
     *
     * <p>{@code startDate} 가 비어 있는 공연도 함께 빠진다. 일정이 없으면 "임박한 순" 이라는 정렬에
     * 자리를 줄 수 없고, 티켓을 살 시점도 판단할 수 없다.
     *
     * <p><b>{@code Pageable} 의 정렬은 비워서 넘긴다.</b> 정렬이 쿼리 안에 박혀 있어, 넘기면 뒤에
     * 덧붙어 중복된다. 순서가 하나뿐이라 호출하는 쪽이 고를 것도 없다.
     */
    @Query(value = """
            select c.id as concertId,
                   c.title as title,
                   c.posterImageKey as posterImageKey,
                   c.startDate as startDate,
                   c.endDate as endDate,
                   v.name as venueName,
                   count(l.id) as listingCount,
                   min(l.price) as lowestPrice
              from TicketListing l
              join l.concert c
              join c.venue v
             where l.status = com.ssafy.timo.domain.transfer.entity.ListingStatus.LISTED
               and l.listedAt < :visibleBefore
               and c.startDate > :now
             group by c.id, c.title, c.posterImageKey, c.startDate, c.endDate, v.name
             order by c.startDate asc, c.id asc
            """,
            countQuery = """
            select count(distinct c.id)
              from TicketListing l
              join l.concert c
             where l.status = com.ssafy.timo.domain.transfer.entity.ListingStatus.LISTED
               and l.listedAt < :visibleBefore
               and c.startDate > :now
            """)
    Page<MarketConcertRow> findConcertSummaries(@Param("now") LocalDateTime now,
                                                @Param("visibleBefore") LocalDateTime visibleBefore,
                                                Pageable pageable);

    /**
     * 공연 하나의 구매 가능한 매물 목록. {@code visibleBefore} 보다 먼저 등록된 것만이다 — 매물은
     * 등록 다음 날 20:00 에 올라가므로 오늘 등록된 매물은 빠진다.
     *
     * <p>정렬(낮은 가격순, 동가는 {@code listingId} 오름차순)은 {@code Pageable} 로 받는다.
     * 동가에 유일 키를 덧붙이지 않으면 페이지를 넘길 때 같은 매물이 두 번 나오거나 건너뛴다.
     *
     * <p>{@code section} 을 함께 읽는다. 목록이 구역명·등급을 쓰는데 지연 로딩으로 두면 매물 수만큼
     * 추가 쿼리가 나간다. 다대일이라 페이징과 함께 써도 안전하다.
     */
    @EntityGraph(attributePaths = "section")
    @Query(value = """
            select l from TicketListing l
             where l.concert.id = :concertId
               and l.status = com.ssafy.timo.domain.transfer.entity.ListingStatus.LISTED
               and l.listedAt < :visibleBefore
            """,
            countQuery = """
            select count(l) from TicketListing l
             where l.concert.id = :concertId
               and l.status = com.ssafy.timo.domain.transfer.entity.ListingStatus.LISTED
               and l.listedAt < :visibleBefore
            """)
    Page<TicketListing> findVisibleByConcertId(@Param("concertId") Long concertId,
                                               @Param("visibleBefore") LocalDateTime visibleBefore,
                                               Pageable pageable);

    /**
     * 매물 상세.
     *
     * <p>상세는 공연·공연장·구역을 한 번에 쓰므로 미리 함께 읽는다.
     *
     * <p><b>상태로 거르지 않는다.</b> 팔렸거나 취소된 매물도 조회된다 — 목록에서 상세로 들어가는
     * 사이에 팔릴 수 있고, 그때 404 를 주면 화면이 "없는 매물" 로 오해한다.
     */
    @Query("""
            select l
              from TicketListing l
              join fetch l.concert c
              join fetch c.venue
              join fetch l.section
             where l.id = :listingId
            """)
    Optional<TicketListing> findDetailById(@Param("listingId") Long listingId);

    /**
     * 매물을 체결 상태로 넘긴다. <b>이 메서드가 동시 구매 방어의 전부다.</b>
     *
     * <p>조회해서 {@code LISTED} 인지 확인한 뒤 UPDATE 하면 두 요청이 같은 매물을 동시에 통과한다.
     * 확인과 전이가 한 문장 안에서 일어나야 선착순이 성립한다. <b>영향 행이 0 이면</b> 남이 먼저
     * 샀거나 판매자가 취소한 것이므로 {@code ListingAlreadyClosedException} 을 던진다.
     * 호출 순서를 "검증 먼저, UPDATE 나중"으로 바꾸지 않는다.
     *
     * <p>{@code updatedAt} 을 직접 넣는 이유는 벌크 UPDATE 가 영속성 컨텍스트를 거치지 않아
     * JPA Auditing 의 {@code @LastModifiedDate} 가 동작하지 않기 때문이다. 넣지 않으면 감사 필드가
     * 등록 시각에 멈춘 채 거짓말을 한다.
     *
     * <p>{@code clearAutomatically} 로 영속성 컨텍스트를 비운다. 벌크 UPDATE 는 DB 만 바꾸므로
     * 비우지 않으면 같은 트랜잭션에서 이 매물을 다시 읽었을 때 <b>여전히 {@code LISTED} 인 옛 상태</b>가
     * 나온다. 대신 같은 컨텍스트의 다른 엔티티도 함께 준영속이 되니, 이 호출 뒤에 쓰는 엔티티는
     * 다시 조회해서 쓴다.
     *
     * @return 영향 행 수. 0 또는 1 이다
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("""
            update TicketListing l
               set l.status = com.ssafy.timo.domain.transfer.entity.ListingStatus.SOLD,
                   l.closedAt = :closedAt,
                   l.updatedAt = :closedAt
             where l.id = :listingId
               and l.status = com.ssafy.timo.domain.transfer.entity.ListingStatus.LISTED
            """)
    int markSoldIfListed(@Param("listingId") Long listingId,
                         @Param("closedAt") LocalDateTime closedAt);

    /**
     * 매물 등록을 취소한다. 행을 지우지 않고 상태만 바꾼다.
     *
     * <p>취소 이력이 남아야 재양도 추적과 CS 가 가능하다. 취소하려는 찰나에 팔렸다면 영향 행이
     * 0 이 되어 {@code ListingAlreadyClosedException} 으로 이어진다.
     *
     * <p>{@code updatedAt} 과 {@code clearAutomatically} 에 대한 설명은
     * {@link #markSoldIfListed(Long, LocalDateTime)} 을 본다.
     *
     * @return 영향 행 수. 0 또는 1 이다
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("""
            update TicketListing l
               set l.status = com.ssafy.timo.domain.transfer.entity.ListingStatus.CANCELED,
                   l.closedAt = :closedAt,
                   l.updatedAt = :closedAt
             where l.id = :listingId
               and l.status = com.ssafy.timo.domain.transfer.entity.ListingStatus.LISTED
            """)
    int markCanceledIfListed(@Param("listingId") Long listingId,
                             @Param("closedAt") LocalDateTime closedAt);

    /**
     * 등록가를 바꾼다. <b>{@code LISTED} 인 매물만 바뀐다.</b>
     *
     * <p>조회해서 {@code LISTED} 인지 확인한 뒤 UPDATE 하면, 가격을 고치려는 찰나에 팔린 매물의
     * 가격이 체결 뒤에 바뀐다. 구매자는 옛 가격에 샀는데 매물에는 새 가격이 남아 <b>체결 기록과
     * 매물이 서로 다른 금액을 말하게 된다</b> — 정산과 CS 가 무엇을 믿어야 할지 알 수 없어진다.
     * 그래서 여기서도 확인과 변경이 한 문장 안에서 일어난다. 영향 행이 0 이면 남이 먼저 샀거나
     * 이미 취소된 것이다.
     *
     * <p>정가 이하인지는 보지 않는다. 기준값인 {@code face_value} 는 등록 시점 스냅샷이라 서비스가
     * 매물을 읽어 판단한다 — 그 검사는 경쟁 상태와 무관하고, 화면에 보여 줄 말이 있는 비즈니스 예외다.
     *
     * <p>{@code updatedAt} 과 {@code clearAutomatically} 에 대한 설명은
     * {@link #markSoldIfListed(Long, LocalDateTime)} 을 본다. 이 호출 뒤에 매물을 다시 쓰려면
     * 새로 조회해야 한다.
     *
     * @return 영향 행 수. 0 또는 1 이다
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("""
            update TicketListing l
               set l.price = :price,
                   l.updatedAt = :updatedAt
             where l.id = :listingId
               and l.status = com.ssafy.timo.domain.transfer.entity.ListingStatus.LISTED
            """)
    int updatePriceIfListed(@Param("listingId") Long listingId,
                            @Param("price") long price,
                            @Param("updatedAt") LocalDateTime updatedAt);

    /**
     * 이 티켓에 진행 중인 등록이 있는지 본다.
     *
     * <p><b>안내용 선검사다.</b> 흔한 경우를 친절한 메시지로 걸러낼 뿐이고, 이것만으로 막으려 하면
     * 확인과 등록 사이에 다른 요청이 끼어든다.
     *
     * <p>실제 보장은 {@code uk_listing_ticket_active} 가 한다 — {@code status='LISTED'} 일 때만 값을
     * 갖는 생성 칼럼에 건 유니크 제약이다({@code TicketListing} 주석). {@code ticket.status} 를
     * {@code OWNED -> LISTED} 로 바꾸는 조건부 UPDATE 를 쓰지 않는 이유는 두 가지다 — {@code Ticket} 에
     * {@code LISTED} 로 가는 전이 메서드가 없고(티켓 도메인은 이쪽 소관이 아니다), 매물의 유일성은
     * 매물 테이블 자신이 지키는 편이 더 강하다. 티켓 상태가 어떻든 뚫리지 않는다.
     */
    boolean existsByTicketIdAndStatus(Long ticketId, ListingStatus status);
}
