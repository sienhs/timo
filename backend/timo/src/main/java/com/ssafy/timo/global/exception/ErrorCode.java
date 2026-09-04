package com.ssafy.timo.global.exception;

import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;

/**
 * 특정 도메인에 속하지 않는 공통 에러 코드.
 *
 * <p>도메인 고유 에러는 해당 도메인 패키지에 별도 enum 을 만들어
 * {@link BaseErrorCode} 를 구현한다. (예: {@code VenueErrorCode.VENUE_NOT_FOUND})
 */
@Getter
@RequiredArgsConstructor
public enum ErrorCode implements BaseErrorCode {

    INVALID_INPUT_VALUE(HttpStatus.BAD_REQUEST, "입력값이 올바르지 않습니다."),
    INTERNAL_SERVER_ERROR(HttpStatus.INTERNAL_SERVER_ERROR, "서버 내부 오류가 발생했습니다.");

    private final HttpStatus status;
    private final String message;
}
