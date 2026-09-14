package com.ssafy.timo.domain.seat.controller;

import com.ssafy.timo.domain.seat.dto.CommandSeatRequestDto;
import com.ssafy.timo.domain.seat.dto.CommandSeatResponseDto;
import com.ssafy.timo.domain.seat.dto.SeatHoldCancelResponseDto;
import com.ssafy.timo.domain.seat.dto.SeatHoldResponseDto;
import com.ssafy.timo.domain.seat.dto.SectionSeatListResponseDto;
import com.ssafy.timo.domain.seat.service.SeatService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 좌석 API (v1, 실제 구현).
 *
 * <p>엔드포인트 매핑과 검증 규약은 {@link SeatApi} 에 있다. 이 클래스는 버전 경로를 정하고
 * 서비스에 위임만 한다. 프론트 연동용 스텁은 {@code /api/v0/seats} 에 같은 규약으로 떠 있다.
 *
 * <p>요청자는 요청 본문이 아니라 {@link com.ssafy.timo.global.security.CurrentMemberProvider}
 * 가 알려 준다. 인증이 붙어도 이 API 규약은 그대로다.
 *
 * <p>요청 검증 실패는 {@link com.ssafy.timo.global.exception.GlobalExceptionHandler} 가
 * Problem Details 로 변환하므로 여기서 따로 처리하지 않는다.
 */
@RestController
@RequestMapping(SeatController.BASE_PATH)
@RequiredArgsConstructor
public class SeatController implements SeatApi {

    static final String BASE_PATH = "/api/v1/seats";

    private final SeatService seatService;

    @Override
    public ResponseEntity<SectionSeatListResponseDto> findSeats(Long concertId, Long sectionId) {
        return ResponseEntity.ok(seatService.findSeats(concertId, sectionId));
    }

    @Override
    public ResponseEntity<SeatHoldResponseDto> hold(Long seatId, Long concertId) {
        return ResponseEntity.ok(seatService.hold(concertId, seatId));
    }

    @Override
    public ResponseEntity<SeatHoldCancelResponseDto> cancelHold(Long seatId, Long concertId) {
        return ResponseEntity.ok(seatService.cancelHold(concertId, seatId));
    }

    @Override
    public ResponseEntity<CommandSeatResponseDto> register(CommandSeatRequestDto request) {
        CommandSeatResponseDto response = seatService.register(request);

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(response);
    }
}
