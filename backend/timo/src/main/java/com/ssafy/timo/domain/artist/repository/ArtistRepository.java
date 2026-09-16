package com.ssafy.timo.domain.artist.repository;

import com.ssafy.timo.domain.artist.entity.Artist;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;

@Repository
public interface ArtistRepository extends JpaRepository<Artist, Long> {

    /**
     * 이름으로 아티스트를 한 번에 찾는다.
     *
     * <p>{@code artist_name} 에는 unique 제약이 없어 동명이인이 들어올 수 있다. 이름만으로 한 명을
     * 특정해야 하는 곳에서는 결과가 둘 이상일 수 있다는 것을 전제로 다뤄야 한다.
     *
     * <p>등록 API 가 없어 시드로만 아티스트가 들어오는 지금은
     * {@link com.ssafy.timo.global.init.LocalDataSeeder} 가 쓴다.
     */
    List<Artist> findAllByNameIn(Collection<String> names);

    /**
     * 조건에 맞는 아티스트를 한 페이지 조회한다. 검색어는 선택값이라 {@code null} 이면 무시한다.
     *
     * <p>{@link Artist} 는 다른 엔티티를 참조하지 않아 fetch join 할 것이 없다. 그래서 여기서는
     * {@code countQuery} 를 따로 주지 않는다 — 조인이 없으니 자동 파생 count 가 그대로 가볍다.
     * 출연 공연처럼 컬렉션이 필요해지면 그때는 목록에 담지 말고 상세에서 준다.
     */
    @Query("""
            select a
            from Artist a
            where (:keyword is null or a.name like concat('%', :keyword, '%'))
            """)
    Page<Artist> findPage(@Param("keyword") String keyword, Pageable pageable);
}
