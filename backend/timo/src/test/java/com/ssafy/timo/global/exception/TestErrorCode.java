package com.ssafy.timo.global.exception;

import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;

/**
 * 도메인별 enum 이 {@link BaseErrorCode} 만 구현하면 예외/핸들러를 손대지 않고
 * 그대로 쓰인다는 것을 확인하기 위한 테스트 전용 에러 코드.
 */
@Getter
@RequiredArgsConstructor
enum TestErrorCode implements BaseErrorCode {

    TARGET_NOT_FOUND(HttpStatus.NOT_FOUND, "테스트 대상을 찾을 수 없습니다.");

    private final HttpStatus status;
    private final String message;
}
