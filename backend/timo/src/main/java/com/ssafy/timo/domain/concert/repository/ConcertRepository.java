package com.ssafy.timo.domain.concert.repository;

import com.ssafy.timo.domain.concert.entity.Concert;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface ConcertRepository extends JpaRepository<Concert, Long> {
}
