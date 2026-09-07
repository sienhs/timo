package com.ssafy.timo.domain.concert.repository;

import com.ssafy.timo.domain.concert.entity.Concert;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

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
     * 조회수를 원자적으로 1 증가시킨다.
     *
     * <p>엔티티를 읽어서 필드를 올리고 다시 저장하면 동시에 들어온 조회가 서로의 증가분을 덮어쓸 수
     * 있다(lost update). DB 에서 바로 {@code view_count = view_count + 1} 을 실행해 이를 피한다.
     *
     * @return 갱신된 행 수. 대상 공연이 없으면 0.
     */
    @Modifying
    @Query("update Concert c set c.viewCount = c.viewCount + 1 where c.id = :id")
    int increaseViewCount(@Param("id") Long id);
}
