package com.ssafy.timo.domain.seat.repository;

import com.ssafy.timo.domain.seat.entity.Section;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface SectionRepository extends JpaRepository<Section, Long> {

    boolean existsByVenueIdAndName(Long venueId, String name);

    List<Section> findAllByVenueId(Long venueId);
}
