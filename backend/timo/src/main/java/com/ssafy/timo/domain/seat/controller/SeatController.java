package com.ssafy.timo.domain.seat.controller;

import com.ssafy.timo.domain.seat.dto.CommandSeatRequestDto;
import com.ssafy.timo.domain.seat.dto.CommandSeatResponseDto;
import com.ssafy.timo.domain.seat.service.SeatService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
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
    @PostMapping
    public ResponseEntity<CommandSeatResponseDto> register(@Valid @RequestBody CommandSeatRequestDto request) {
        CommandSeatResponseDto response = seatService.register(request);

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(response);
    }
}
