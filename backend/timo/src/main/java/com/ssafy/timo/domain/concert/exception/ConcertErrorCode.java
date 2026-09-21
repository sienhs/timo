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
    INVALID_TICKET_OPEN_TIME(HttpStatus.BAD_REQUEST, "예매 오픈은 공연 시작 전이어야 합니다."),
    CONCERT_NOT_FOUND(HttpStatus.NOT_FOUND, "존재하지 않는 공연입니다."),

    /**
     * 소장품 소재는 그 공연 티켓을 지금 가진 사람만 본다. 공연 자체는 공개라 존재를 숨길 이유가 없어
     * 404 가 아니라 403 이다.
     */
    CONCERT_KIT_FORBIDDEN(HttpStatus.FORBIDDEN, "이 공연의 티켓을 보유하고 있지 않습니다.");

    private final HttpStatus status;
    private final String message;
}
