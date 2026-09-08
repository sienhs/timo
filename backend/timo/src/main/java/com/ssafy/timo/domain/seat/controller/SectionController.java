package com.ssafy.timo.domain.seat.controller;

import com.ssafy.timo.domain.seat.dto.SectionListResponseDto;
import com.ssafy.timo.domain.seat.service.SeatService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 구역 API.
 *
 * <p>좌석과 같은 도메인이지만 경로를 나눈다. 한 URL 이 파라미터에 따라 구역을 주기도 하고 좌석을
 * 주기도 하면 응답 스키마가 둘이 되어 클라이언트가 무엇이 올지 미리 알 수 없다.
 *
 * <p>요청 검증 실패는 {@link com.ssafy.timo.global.exception.GlobalExceptionHandler} 가
 * Problem Details 로 변환하므로 여기서 따로 처리하지 않는다.
 */
@RestController
@RequestMapping(SectionController.BASE_PATH)
@RequiredArgsConstructor
public class SectionController {

    static final String BASE_PATH = "/api/v1/sections";

    private final SeatService seatService;

    /**
     * 공연장의 구역을 잔여석과 함께 조회한다. 구역 선택 화면이 쓴다.
     *
     * <p>개별 좌석은 담기지 않는다. 구역을 고른 뒤 {@code GET /api/v1/seats?sectionId=} 로 받는다.
     */
    @GetMapping
    public ResponseEntity<SectionListResponseDto> findSections(@RequestParam Long venueId) {
        return ResponseEntity.ok(seatService.findSections(venueId));
    }
}
