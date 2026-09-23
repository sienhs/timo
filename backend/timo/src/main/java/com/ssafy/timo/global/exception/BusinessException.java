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

    /**
     * 재시도를 권할 때만 채운다({@code null} 이면 안 채운다). {@link GlobalExceptionHandler} 가
     * {@code Retry-After} 헤더로 그대로 내보낸다. 아무 실패에나 채우면 안 된다 - 원인이 확실하고
     * ("지금 자리가 없다") 곧 풀린다는 근거가 있을 때만 쓴다. 이유를 모르는 실패에 아무 숫자나
     * 주면 클라이언트가 그 숫자를 근거 있는 값으로 믿고 재시도 로직을 짠다.
     */
    private final Long retryAfterSeconds;

    public BusinessException(BaseErrorCode errorCode) {
        this(errorCode, errorCode.getMessage(), null);
    }

    /** 같은 코드지만 상황별로 구체적인 사유를 담고 싶을 때. */
    public BusinessException(BaseErrorCode errorCode, String message) {
        this(errorCode, message, null);
    }

    /** 재시도 대기 시간(초)까지 함께 담을 때. */
    public BusinessException(BaseErrorCode errorCode, String message, Long retryAfterSeconds) {
        super(message);
        this.errorCode = errorCode;
        this.retryAfterSeconds = retryAfterSeconds;
    }
}
