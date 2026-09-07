package com.ssafy.timo.domain.concert.exception;

import com.ssafy.timo.global.exception.BaseErrorCode;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;

/** 공연 도메인 에러 코드. */
@Getter
@RequiredArgsConstructor
public enum ConcertErrorCode implements BaseErrorCode {

    INVALID_CONCERT_PERIOD(HttpStatus.BAD_REQUEST, "공연 종료일은 시작일보다 빠를 수 없습니다."),
    INVALID_TICKET_OPEN_TIME(HttpStatus.BAD_REQUEST, "예매 오픈은 공연 시작 전이어야 합니다.");

    private final HttpStatus status;
    private final String message;
}
