package com.ssafy.timo.domain.venue.repository;

import com.ssafy.timo.domain.venue.entity.Venue;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface VenueRepository extends JpaRepository<Venue, Long> {

    boolean existsByName(String name);

    /**
     * 이름으로 공연장을 찾는다. {@code venue_name} 에 unique 제약이 있어 결과는 최대 하나다.
     *
     * <p>이미 있으면 그대로 쓰고 없을 때만 등록하는 시드 경로에서 쓴다
     * ({@link com.ssafy.timo.global.init.LocalDataSeeder}). 등록 API 는 중복을 409 로 막아야 해서
     * {@link #existsByName(String)} 을 그대로 쓴다.
     */
    Optional<Venue> findByName(String name);
}
