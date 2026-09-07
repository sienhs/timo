package com.ssafy.timo.domain.venue.repository;

import com.ssafy.timo.domain.venue.entity.Venue;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface VenueRepository extends JpaRepository<Venue, Long> {

    boolean existsByName(String name);
}
