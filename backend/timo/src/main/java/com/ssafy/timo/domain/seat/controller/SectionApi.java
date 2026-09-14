package com.ssafy.timo.domain.seat.controller;

import com.ssafy.timo.domain.seat.dto.SectionListResponseDto;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;

/**
 * 구역 API 규약.
 *
 * <p>좌석과 같은 도메인이지만 경로를 나눈다. 한 URL 이 파라미터에 따라 구역을 주기도 하고 좌석을
 * 주기도 하면 응답 스키마가 둘이 되어 클라이언트가 무엇이 올지 미리 알 수 없다.
 *
 * <p>메서드 매핑과 요청 검증 애노테이션은 여기에만 둔다. 구현체(v1 실제 컨트롤러, v0 스텁)는
 * 클래스 레벨 {@code @RequestMapping} 으로 버전 경로만 정하고 이 메서드들을 그대로 오버라이드한다.
 * 자세한 이유는 {@link com.ssafy.timo.domain.venue.controller.VenueApi} 참고.
 */
public interface SectionApi {

    /**
     * 한 공연의 구역을 잔여석과 함께 조회한다. 구역 선택 화면이 쓴다.
     *
     * <p>공연장이 아니라 <b>공연</b>을 받는다. 구역 자체는 공연장 것이지만 잔여석은 공연마다 다르다 —
     * 같은 공연장에서 두 공연이 열리면 같은 구역의 남은 자리 수가 각각이다.
     *
     * <p>개별 좌석은 담기지 않는다. 구역을 고른 뒤 {@link SeatApi#findSeats(Long, Long)} 로 받는다.
     */
    @GetMapping
    ResponseEntity<SectionListResponseDto> findSections(@RequestParam Long concertId);
}
