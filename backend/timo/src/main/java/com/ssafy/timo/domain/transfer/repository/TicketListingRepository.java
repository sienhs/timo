package com.ssafy.timo.domain.transfer.repository;

import com.ssafy.timo.domain.transfer.entity.ListingStatus;
import com.ssafy.timo.domain.transfer.entity.TicketListing;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;

@Repository
public interface TicketListingRepository extends JpaRepository<TicketListing, Long> {

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
     * 이 티켓에 진행 중인 등록이 있는지 본다.
     *
     * <p>MySQL 에 부분 유니크 인덱스가 없어 "티켓당 진행 중 등록은 하나"를 DB 제약으로 걸 수 없다.
     * 실제 보장은 {@code ticket.status} 를 {@code ISSUED -> LISTED} 로 바꾸는 조건부 UPDATE 가 하고,
     * 이 메서드는 <b>안내용 선검사와 점검에만</b> 쓴다. 이것만으로 막으려 하면 확인과 등록 사이에
     * 다른 요청이 끼어든다.
     */
    boolean existsByTicketIdAndStatus(Long ticketId, ListingStatus status);
}
