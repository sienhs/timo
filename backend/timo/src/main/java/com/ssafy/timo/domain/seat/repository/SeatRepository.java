package com.ssafy.timo.domain.seat.repository;

import com.ssafy.timo.domain.seat.entity.Seat;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface SeatRepository extends JpaRepository<Seat, Long> {

    long countBySectionId(Long sectionId);
}
