package com.ssafy.timo.domain.concert.repository;

import com.ssafy.timo.domain.concert.dto.ConcertOpenRow;
import com.ssafy.timo.domain.concert.dto.ConcertStartRow;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.entity.ConcertStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface ConcertRepository extends JpaRepository<Concert, Long> {

    /**
     * 상세 조회 시 항상 필요한 공연장만 fetch join 한다.
     *
     * <p>출연 아티스트·이미지까지 한 쿼리에 fetch join 하면 컬렉션 두 개를 동시에 fetch join 하는
     * 꼴이라 카티션 곱 문제(MultipleBagFetchException)가 난다. 단건 조회는 결과가 항상 하나뿐이라
     * 그 둘은 지연 로딩으로 남겨 둬도 늘어나는 쿼리가 상수 개다 — N+1 이 문제가 되는 목록 조회와는
     * 다르다.
     */
    @Query("select c from Concert c join fetch c.venue where c.id = :id")
    Optional<Concert> findByIdWithVenue(@Param("id") Long id);

    /**
     * 시작 시각이 {@code from} 이상 {@code to} 이하인 공연을, 지정한 상태만 빼고, 시작이 빠른 순으로.
     * 알림 스윕이 "지금 알릴 공연" 을 찾는 데 쓴다. 경계는 양쪽 다 포함한다. 경계에 걸친 공연이 빠지는 것보다
     * 한 번 더 걸리는 편이 낫고, 중복은 알림 저장이 막는다.
     *
     * <p>알림 시각을 시작 시각에서 역산한 범위로 바꿔서 넘긴다. 컬럼에 함수를 걸어 계산하면 인덱스를 못 탄다.
     */
    @Query("""
            select c.id as id, c.title as title, c.startDate as startDate
              from Concert c
             where c.startDate between :from and :to
               and c.status <> :excluded
             order by c.startDate, c.id
            """)
    List<ConcertStartRow> findStartRowsBetween(@Param("from") LocalDateTime from,
                                               @Param("to") LocalDateTime to,
                                               @Param("excluded") ConcertStatus excluded);

    /**
     * 예매 오픈 시각이 {@code from} 이상 {@code to} 이하인 공연을, 지정한 상태만 빼고, 오픈이 빠른 순으로.
     * 경계는 양쪽 다 포함한다. 알림 스윕이 곧 열릴 공연 후보를 좁히는 데 쓰고, 알림 시각이 정확히 지금
     * 범위에 드는지는 호출부가 하나씩 가린다.
     */
    @Query("""
            select c.id as id, c.title as title, c.openAt as openAt
              from Concert c
             where c.openAt between :from and :to
               and c.status <> :excluded
             order by c.openAt, c.id
            """)
    List<ConcertOpenRow> findOpenRowsBetween(@Param("from") LocalDateTime from,
                                             @Param("to") LocalDateTime to,
                                             @Param("excluded") ConcertStatus excluded);

    /**
     * 조건에 맞는 공연을 한 페이지 조회한다. 조건은 모두 선택값이라 {@code null} 이면 무시한다.
     *
     * <p>목록 카드가 공연장 이름을 쓰므로 공연장은 fetch join 한다. 공연장은 다대일이라 조인해도
     * 행이 늘지 않아 DB 에서 limit 을 그대로 걸 수 있다 — 컬렉션(아티스트·이미지)을 함께
     * fetch join 하면 행이 불어나 페이지 크기가 어긋나므로, 그 둘은 목록 응답에 담지 않는다.
     *
     * <p>{@code countQuery} 를 직접 준다. fetch join 이 들어간 쿼리에서 count 를 자동으로
     * 만들어 내려 하면 조인이 그대로 남아 불필요하게 무겁고, 파생에 실패할 수도 있다.
     * 개수를 세는 데는 공연장 조인이 필요 없다.
     */
    @Query(value = """
            select c
            from Concert c
            join fetch c.venue
            where (:genre is null or c.genre = :genre)
              and (:status is null or c.status = :status)
              and (:keyword is null or c.title like concat('%', :keyword, '%'))
            """,
            countQuery = """
            select count(c)
            from Concert c
            where (:genre is null or c.genre = :genre)
              and (:status is null or c.status = :status)
              and (:keyword is null or c.title like concat('%', :keyword, '%'))
            """)
    Page<Concert> findPage(@Param("genre") ConcertGenre genre,
                           @Param("status") ConcertStatus status,
                           @Param("keyword") String keyword,
                           Pageable pageable);

    /**
     * 끝난 공연을 {@code CLOSED} 로 내린다. {@code ConcertStatusScheduler} 가 주기적으로 부른다.
     *
     * <p>{@code CANCELED} 는 제외한다. 취소는 사람이 내린 결정인데 날짜가 지났다고 "종료" 로
     * 덮으면 왜 열리지 않았는지가 사라진다. 나머지는 모두 대상이다 - 예매를 열어 본 적 없는
     * {@code SCHEDULED} 공연도 날짜가 지났으면 지난 공연 목록에 있어야 한다. 이미
     * {@code CLOSED} 인 행도 빼는데, 그러면 반환값이 "이번에 실제로 바뀐 건수" 가 된다.
     *
     * <p>{@code endDate} 가 없는 공연은 건드리지 않는다. 언제 끝나는지 모르는 것을 끝났다고
     * 단정할 수는 없다.
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            update Concert c
            set c.status = com.ssafy.timo.domain.concert.entity.ConcertStatus.CLOSED
            where c.status <> com.ssafy.timo.domain.concert.entity.ConcertStatus.CANCELED
              and c.status <> com.ssafy.timo.domain.concert.entity.ConcertStatus.CLOSED
              and c.endDate is not null
              and c.endDate <= :now
            """)
    int closeFinished(@Param("now") LocalDateTime now);

    /**
     * 오픈 시각이 지난 공연을 {@code ON_SALE} 로 올린다. {@code ConcertStatusScheduler} 가 부른다.
     *
     * <p>온체인 등록이 끝난 공연만 대상이다 - {@code organizer} 와 {@code showId} 가 채워진 것,
     * 즉 {@code Concert.isReadyForBooking} 과 같은 조건이다. 그게 없는 공연을 목록에 "예매 중" 으로
     * 내보내면 눌러 보는 사람마다 500 을 받는다. {@code ReservationServiceImpl.create} 가 그 조합을
     * 깨진 불변식으로 보고 {@code IllegalStateException} 을 던지기 때문이다.
     *
     * <p>이 컬럼의 {@code ON_SALE} 은 "예매 기간에 들어섰다" 는 거친 라벨이다. 공연 시작
     * {@code Concert.BOOKING_CUTOFF_HOURS} 시간 전 마감까지는 반영하지 않으므로, 마감부터 공연
     * 종료까지는 컬럼이 {@code ON_SALE} 인데 실제 선점·결제는 막혀 있다. 그 구간을 컬럼으로
     * 구분하려면 {@code ConcertStatus} 에 값을 하나 더 만들어 클라이언트 계약까지 바꿔야 한다.
     * 그 구간의 정확한 가능 여부는 {@code Concert.bookingBlockReason} 이 요청마다 답한다.
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            update Concert c
            set c.status = com.ssafy.timo.domain.concert.entity.ConcertStatus.ON_SALE
            where c.status = com.ssafy.timo.domain.concert.entity.ConcertStatus.SCHEDULED
              and c.openAt is not null
              and c.openAt <= :now
              and (c.endDate is null or c.endDate > :now)
              and c.organizer is not null
              and c.showId is not null
            """)
    int openScheduled(@Param("now") LocalDateTime now);

    /**
     * 팔 자리가 남지 않은 공연을 {@code SOLD_OUT} 으로 올린다. {@code ConcertStatusScheduler} 가 부른다.
     *
     * <p>판정은 "이 공연장의 좌석 수 = 이 공연에서 <b>결제된</b> 좌석 수" 다. 즉 {@code PAID} 만
     * 센다. 취소된 주문은 자리를 놓아 주므로({@code ReservationStatus} 주석) 팔린 자리가 아니고,
     * 해제를 기다리는 취소 자리도 곧 다시 팔 자리라 남은 것으로 본다. 선점도 마찬가지다 -
     * 결제 중인 자리를 팔렸다고 보면 5분 뒤 만료에 맞춰 되돌려야 한다.
     *
     * <p>정리하면 세지 않는 것은 모두 <b>일시적인 잠금</b>이다. 잠금이 풀려 자리가 돌아오는 것과
     * 매진 판정이 엇갈리지 않으려면, 되돌릴 수 없는 사실인 {@code PAID} 만 세는 것이 맞다.
     *
     * <p>이 전이는 한 방향이 아니다. 취소가 나면 {@code PAID} 가 줄어 다시 팔 자리가 생기므로
     * {@link #reopenSoldOut()} 이 되돌린다.
     *
     * <p>좌석이 아직 등록되지 않은 공연장은 제외한다. 좌석 수가 0 이면 "전부 팔렸다" 가 공허하게
     * 참이 되어, 자리가 하나도 없는 공연이 매진으로 찍힌다.
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            update Concert c
            set c.status = com.ssafy.timo.domain.concert.entity.ConcertStatus.SOLD_OUT
            where c.status = com.ssafy.timo.domain.concert.entity.ConcertStatus.ON_SALE
              and (select count(s) from Seat s where s.section.venue.id = c.venue.id) > 0
              and (select count(s) from Seat s where s.section.venue.id = c.venue.id)
                  = (select count(distinct r.seat.id)
                     from Reservation r
                     where r.concert.id = c.id
                       and r.status = com.ssafy.timo.domain.reservation.entity.ReservationStatus.PAID)
            """)
    int markSoldOut();

    /**
     * 취소로 자리가 다시 생긴 매진 공연을 {@code ON_SALE} 로 되돌린다.
     * {@code ConcertStatusScheduler} 가 부른다.
     *
     * <p>{@link #markSoldOut()} 을 그대로 뒤집은 조건이다 - 결제된 좌석이 전체 좌석보다 적으면
     * 팔 자리가 남아 있다. 해제를 기다리는 동안에도 되돌린다. 그 자리는 해제 시각이 지나면
     * 아무나 살 수 있게 되므로 매진이 아니다.
     *
     * <p>온체인 등록 조건을 {@link #openScheduled} 와 똑같이 건다. {@code SOLD_OUT} 이 되려면
     * {@code ON_SALE} 을 거쳤어야 하므로 이미 갖춰져 있는 것이 정상이지만, 시드나 부트스트랩 SQL 이
     * 상태를 직접 심을 수 있어 그 경로로 들어온 행까지 예매 중으로 올리지는 않는다.
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            update Concert c
            set c.status = com.ssafy.timo.domain.concert.entity.ConcertStatus.ON_SALE
            where c.status = com.ssafy.timo.domain.concert.entity.ConcertStatus.SOLD_OUT
              and c.organizer is not null
              and c.showId is not null
              and (select count(s) from Seat s where s.section.venue.id = c.venue.id)
                  > (select count(distinct r.seat.id)
                     from Reservation r
                     where r.concert.id = c.id
                       and r.status = com.ssafy.timo.domain.reservation.entity.ReservationStatus.PAID)
            """)
    int reopenSoldOut();

    /**
     * 이 회원이 <b>지금</b> 이 공연의 티켓을 가지고 있으면 1 이상, 아니면 0.
     *
     * <p>소재({@code kit})를 볼 자격을 가리는 데 쓴다. 입장 여부는 보지 않는다 - 소재는 제작을
     * 시작하기 전에 고르는 것이라 공연 전에도 열려 있어야 하고, 만들 수 있는지는 굿즈 쪽이
     * {@code USED} 로 따로 가린다.
     *
     * <p>귀속 판정은 {@code ticket.owner_member_id} 를 그대로 따른다 - 양도되면 그 컬럼이 바뀌므로
     * 구매자가 소재를 보고 원 예매자는 못 본다.
     */
    @Query("""
            select count(t)
              from Ticket t
             where t.reservation.concert.id = :concertId
               and t.ownerMemberId = :memberId
            """)
    long countCurrentOwnershipOfConcert(@Param("memberId") Long memberId,
                                        @Param("concertId") Long concertId);
}
