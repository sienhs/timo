package com.ssafy.timo.domain.artist.repository;

import com.ssafy.timo.domain.artist.entity.Artist;

import org.springframework.data.jpa.repository.JpaRepository;
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
}
