package com.ssafy.timo.global.security;

import com.ssafy.timo.global.security.exception.AuthErrorCode;
import com.ssafy.timo.global.security.exception.AuthException;
import java.net.URI;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * 인증·인가 실패 전용 예외 처리.
 *
 * <p>{@code GlobalExceptionHandler} 가 이미 모든 {@code BusinessException} 을 처리하지만,
 * 그 응답에는 {@code errorCode} 가 없다. 앱이 만료와 무효를 구분하려면 안정적인 식별자가
 * 필요한데, 지금 유일한 단서인 {@code exception} 은 자바 클래스명이라 리팩터링 한 번에
 * 앱이 조용히 깨진다.
 *
 * <p>그렇다고 {@code GlobalExceptionHandler} 에 {@code errorCode} 를 넣으면 공연·공연장·좌석 등
 * 다른 담당자의 API 응답 스키마까지 한꺼번에 바뀐다. 그래서 인증 응답에만 필드를 얹는 이 advice 를
 * 따로 두고, 나머지 도메인 응답은 건드리지 않는다.
 *
 * <p>{@link Order} 가 필수다. {@link AuthException} 은 {@code BusinessException} 의 하위 타입이라
 * 이 advice 가 먼저 조회되지 않으면 {@code GlobalExceptionHandler} 가 먼저 잡아 가고
 * {@code errorCode} 가 빠진다.
 *
 * <p><b>주의</b>: 응답 모양은 {@code GlobalExceptionHandler} 와 맞춰 둔 것이다.
 * 거기서 필드를 바꾸면 여기도 같이 바꿔야 두 응답이 갈라지지 않는다.
 *
 * <pre>
 * {
 *   "type": "about:blank",
 *   "title": "Unauthorized",
 *   "status": 401,
 *   "instance": "/api/v1/venues/1",
 *   "errorCode": "TOKEN_EXPIRED",
 *   "errorMessage": "인증이 만료되었습니다.",
 *   "timestamp": "2026-09-08 09:35:15",
 *   "exception": "TokenExpiredException"
 * }
 * </pre>
 */
@Slf4j
@Order(Ordered.HIGHEST_PRECEDENCE)
@RestControllerAdvice
public class AuthExceptionHandler {

    private static final URI BLANK_TYPE = URI.create("about:blank");

    private static final DateTimeFormatter TIMESTAMP_FORMAT =
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
    private static final ZoneId ZONE = ZoneId.of("Asia/Seoul");

    @ExceptionHandler(AuthException.class)
    public ProblemDetail handleAuthException(AuthException e) {
        AuthErrorCode errorCode = e.getErrorCode();

        ProblemDetail problemDetail = ProblemDetail.forStatus(errorCode.getStatus());
        problemDetail.setType(BLANK_TYPE);
        problemDetail.setProperty("errorCode", errorCode.name());
        problemDetail.setProperty("errorMessage", e.getMessage());
        problemDetail.setProperty("timestamp", LocalDateTime.now(ZONE).format(TIMESTAMP_FORMAT));
        problemDetail.setProperty("exception", e.getClass().getSimpleName());

        return problemDetail;
    }
}
