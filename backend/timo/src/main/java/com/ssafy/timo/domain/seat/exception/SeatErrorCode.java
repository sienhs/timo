package com.ssafy.timo.domain.seat.exception;

import com.ssafy.timo.global.exception.BaseErrorCode;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;

/** 좌석·구역 도메인 에러 코드. */
@Getter
@RequiredArgsConstructor
public enum SeatErrorCode implements BaseErrorCode {

    SEAT_NOT_FOUND(HttpStatus.NOT_FOUND, "존재하지 않는 좌석입니다."),
    SEAT_NOT_HOLDABLE(HttpStatus.CONFLICT, "이미 선택된 좌석입니다."),
    SEAT_HOLD_NOT_OWNED(HttpStatus.FORBIDDEN, "본인이 선점한 좌석이 아닙니다."),
    SEAT_NOT_HELD(HttpStatus.CONFLICT, "선점 상태가 아닌 좌석입니다."),
    SECTION_NOT_FOUND(HttpStatus.NOT_FOUND, "존재하지 않는 구역입니다."),
    SECTION_NAME_DUPLICATED(HttpStatus.CONFLICT, "이미 등록된 구역명입니다."),
    DUPLICATED_SEAT_POSITION(HttpStatus.BAD_REQUEST, "같은 좌석 자리가 두 번 들어왔습니다."),
    SEAT_POSITION_OUT_OF_BOUNDS(HttpStatus.BAD_REQUEST, "좌석 자리가 구역의 배치 범위를 벗어났습니다.");

    private final HttpStatus status;
    private final String message;
}
