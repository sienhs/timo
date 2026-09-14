package com.ssafy.timo.domain.seat.controller;

import com.ssafy.timo.domain.seat.dto.SectionListResponseDto;
import com.ssafy.timo.domain.seat.service.SeatService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 구역 API (v1, 실제 구현).
 *
 * <p>엔드포인트 매핑과 검증 규약은 {@link SectionApi} 에 있다. 이 클래스는 버전 경로를 정하고
 * 서비스에 위임만 한다. 프론트 연동용 스텁은 {@code /api/v0/sections} 에 같은 규약으로 떠 있다.
 *
 * <p>요청 검증 실패는 {@link com.ssafy.timo.global.exception.GlobalExceptionHandler} 가
 * Problem Details 로 변환하므로 여기서 따로 처리하지 않는다.
 */
@RestController
@RequestMapping(SectionController.BASE_PATH)
@RequiredArgsConstructor
public class SectionController implements SectionApi {

    static final String BASE_PATH = "/api/v1/sections";

    private final SeatService seatService;

    @Override
    public ResponseEntity<SectionListResponseDto> findSections(Long concertId) {
        return ResponseEntity.ok(seatService.findSections(concertId));
    }
}
