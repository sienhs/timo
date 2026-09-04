package com.ssafy.timo.global.exception;

import lombok.Getter;

/**
 * 비즈니스 규칙 위반을 나타내는 예외.
 *
 * <p>서비스 계층에서 던지면 {@link GlobalExceptionHandler} 가 에러 코드의 상태로 응답한다.
 * 구체 enum 이 아닌 {@link BaseErrorCode} 를 받으므로 도메인별 에러 코드를 그대로 넘길 수 있다.
 */
@Getter
public class BusinessException extends RuntimeException {

    private final BaseErrorCode errorCode;

    public BusinessException(BaseErrorCode errorCode) {
        super(errorCode.getMessage());
        this.errorCode = errorCode;
    }

    /** 같은 코드지만 상황별로 구체적인 사유를 담고 싶을 때. */
    public BusinessException(BaseErrorCode errorCode, String message) {
        super(message);
        this.errorCode = errorCode;
    }
}
