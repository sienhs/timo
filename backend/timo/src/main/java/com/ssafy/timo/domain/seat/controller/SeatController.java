package com.ssafy.timo.domain.seat.controller;

import com.ssafy.timo.domain.seat.dto.CommandSeatRequestDto;
import com.ssafy.timo.domain.seat.dto.CommandSeatResponseDto;
import com.ssafy.timo.domain.seat.dto.SectionSeatListResponseDto;
import com.ssafy.timo.domain.seat.service.SeatService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 좌석 API.
 *
 * <p>요청 검증 실패는 {@link com.ssafy.timo.global.exception.GlobalExceptionHandler} 가
 * Problem Details 로 변환하므로 여기서 따로 처리하지 않는다.
 */
@RestController
@RequestMapping(SeatController.BASE_PATH)
@RequiredArgsConstructor
public class SeatController {

    static final String BASE_PATH = "/api/v1/seats";

    private final SeatService seatService;

    /**
     * 공연장의 구역과 좌석을 등록한다.
     *
     * <p>공연장·공연 등록과 달리 Location 헤더를 싣지 않는다. 한 번의 호출로 구역 여러 개와 좌석 수천 건이
     * 만들어지므로 가리킬 단일 리소스가 없다. 만들어진 구역은 응답 본문의 {@code sections} 에서 확인한다.
     */
    /**
     * 구역 하나의 좌석을 배치도 순서(행 -> 자리)로 조회한다.
     *
     * <p>{@code sectionId} 는 필수다. 좌석은 언제나 구역 단위로 조회한다 — 공연장 전체 좌석은
     * 수만 건이 될 수 있어 한 응답에 실을 크기가 아니다. 구역 목록은
     * {@code GET /api/v1/sections?venueId=} 에서 받는다.
     *
     * <p>페이지로 나누지 않는다. 배치도는 좌석이 전부 있어야 그려진다.
     */
    @GetMapping
    public ResponseEntity<SectionSeatListResponseDto> findSeats(@RequestParam Long sectionId) {
        return ResponseEntity.ok(seatService.findSeats(sectionId));
    }

    @PostMapping
    public ResponseEntity<CommandSeatResponseDto> register(@Valid @RequestBody CommandSeatRequestDto request) {
        CommandSeatResponseDto response = seatService.register(request);

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(response);
    }
}
