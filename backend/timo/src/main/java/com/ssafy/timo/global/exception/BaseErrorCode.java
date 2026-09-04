package com.ssafy.timo.global.exception;

import org.springframework.http.HttpStatus;

/**
 * 에러 코드 공통 규약.
 *
 * <p>도메인이 커지면 도메인별 enum 을 만들어 이 인터페이스를 구현한다.
 * {@link BusinessException} 과 {@link GlobalExceptionHandler} 는 구체 enum 이 아닌
 * 이 타입에만 의존하므로, 새 enum 을 추가해도 예외/핸들러는 손대지 않는다.
 */
public interface BaseErrorCode {

    /** 응답으로 내려갈 HTTP 상태. */
    HttpStatus getStatus();

    /** 사용자에게 보여줄 기본 메시지. 응답의 errorMessage 로 나간다. */
    String getMessage();

    /**
     * enum 상수명. 응답에는 싣지 않고 로그 식별용으로만 쓴다.
     * enum 이 구현하면 {@link Enum#name()} 이 자동으로 충족한다.
     */
    String name();
}
