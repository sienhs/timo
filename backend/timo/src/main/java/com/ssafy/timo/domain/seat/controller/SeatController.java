package com.ssafy.timo.domain.seat.controller;

import com.ssafy.timo.domain.seat.dto.CommandSeatRequestDto;
import com.ssafy.timo.domain.seat.dto.CommandSeatResponseDto;
import com.ssafy.timo.domain.seat.dto.SeatHoldCancelResponseDto;
import com.ssafy.timo.domain.seat.dto.SeatHoldResponseDto;
import com.ssafy.timo.domain.seat.dto.SectionSeatListResponseDto;
import com.ssafy.timo.domain.seat.service.SeatService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
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

    /**
     * 좌석을 선점한다. 5 분 동안 다른 회원이 잡을 수 없다.
     *
     * <p>요청자는 요청 본문이 아니라 {@link com.ssafy.timo.global.security.CurrentMemberProvider}
     * 가 알려 준다. 인증이 붙어도 이 API 규약은 그대로다.
     *
     * <p>한 계정은 좌석 하나만 잡을 수 있어, 새로 잡으면 이전 선점이 함께 풀린다. 풀린 좌석은
     * 응답의 {@code releasedSeatId} 로 알려 준다.
     *
     * <p>이미 내가 잡고 있는 좌석을 다시 부르면 만료 시각이 5 분 뒤로 갱신된다.
     */
    @PostMapping("/{seatId}/hold")
    public ResponseEntity<SeatHoldResponseDto> hold(@PathVariable Long seatId) {
        return ResponseEntity.ok(seatService.hold(seatId));
    }

    /**
     * 좌석 선점을 취소한다. 자리는 즉시 예매 가능으로 돌아간다.
     *
     * <p>본문을 내려준다. 화면이 좌석 목록을 다시 받지 않고도 풀린 자리를 바로 다시 그리기 위해서다.
     *
     * <p>이미 빈 자리(아무도 잡지 않았거나 선점이 만료된 좌석)를 취소해도 200 이다. 취소는 멱등하다.
     * 남이 잡고 있거나 결제까지 끝난 좌석은 403 으로 거절한다.
     */
    @DeleteMapping("/{seatId}/hold")
    public ResponseEntity<SeatHoldCancelResponseDto> cancelHold(@PathVariable Long seatId) {
        return ResponseEntity.ok(seatService.cancelHold(seatId));
    }

    @PostMapping
    public ResponseEntity<CommandSeatResponseDto> register(@Valid @RequestBody CommandSeatRequestDto request) {
        CommandSeatResponseDto response = seatService.register(request);

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(response);
    }
}
