package com.ssafy.timo.domain.seat.repository;

import com.ssafy.timo.domain.seat.entity.Section;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface SectionRepository extends JpaRepository<Section, Long> {

    boolean existsByVenueIdAndName(Long venueId, String name);

    List<Section> findAllByVenueId(Long venueId);

    /**
     * 공연장의 구역을 등록 순서로 읽는다.
     *
     * <p>이름순으로 정렬하지 않는다. 문자열 정렬은 "10층"을 "2층"보다 앞에 놓아 화면 순서가 어긋난다.
     * 등록 순서는 배치도를 만든 순서라 대체로 화면 순서와 맞고, 무엇보다 항상 같은 순서를 보장한다.
     */
    List<Section> findAllByVenueIdOrderByIdAsc(Long venueId);
}
