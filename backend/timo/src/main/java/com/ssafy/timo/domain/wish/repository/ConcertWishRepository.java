package com.ssafy.timo.domain.wish.repository;

import com.ssafy.timo.domain.wish.entity.ConcertWish;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ConcertWishRepository extends JpaRepository<ConcertWish, Long> {

    /**
     * 내 찜 목록. 공연 카드에 공연장 이름이 실리므로 공연과 공연장을 함께 읽는다(다대일만 fetch join).
     *
     * <p>정렬은 최근 찜한 순이고 {@code id} 를 덧붙인다. 같은 초에 두 건을 찜하면 순서가 흔들려
     * 페이지를 넘길 때 같은 카드가 두 번 나올 수 있다.
     */
    @Query(value = """
            select w
              from ConcertWish w
              join fetch w.concert c
              join fetch c.venue
             where w.member.id = :memberId
             order by w.createdAt desc, w.id desc
            """,
            countQuery = """
            select count(w) from ConcertWish w where w.member.id = :memberId
            """)
    Page<ConcertWish> findPageOfMember(@Param("memberId") Long memberId, Pageable pageable);

    boolean existsByMemberIdAndConcertId(Long memberId, Long concertId);

    /**
     * 찜 해제. 영향 행 수를 돌려주므로 없던 찜을 지워도 예외가 아니다 — 해제는 멱등이어야 한다.
     * 하트를 두 번 눌러 요청이 겹쳐도 뒤의 것이 실패하면 안 된다.
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("delete from ConcertWish w where w.member.id = :memberId and w.concert.id = :concertId")
    int deleteByMemberIdAndConcertId(@Param("memberId") Long memberId, @Param("concertId") Long concertId);
}
