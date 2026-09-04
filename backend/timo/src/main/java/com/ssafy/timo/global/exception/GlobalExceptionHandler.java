package com.ssafy.timo.global.exception;

import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;

import java.net.URI;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;

/**
 * 전역 예외 처리. 응답은 RFC 9457 Problem Details(application/problem+json) 를 사용한다.
 *
 * <p>{@link ResponseEntityExceptionHandler} 를 상속해 Spring 내장 예외(405, 415, 본문 파싱 실패 등)도
 * 같은 포맷으로 나간다. 표준 필드(type/title/status/instance) 위에 확장 속성을 싣고,
 * 메시지는 표준 detail 대신 errorMessage 로 내보내므로 detail 은 비워 둔다.
 *
 * <pre>
 * {
 *   "type": "about:blank",
 *   "title": "Bad Request",
 *   "status": 400,
 *   "instance": "/api/mini-room-component",
 *   "errorMessage": "이미 배치된 아이템이에요.",
 *   "timestamp": "2025-08-08 15:56:25",
 *   "exception": "DuplicateComponentException"
 * }
 * </pre>
 *
 * <p>{@code exception} 은 실제로 던져진 예외의 클래스명이다. 위 예시처럼 구체적인 이름이 찍히게 하려면
 * {@link BusinessException} 을 상속한 예외를 만들어 던진다.
 *
 * <p>{@code @Valid} 검증 실패일 때만 어느 필드가 왜 틀렸는지 {@code errors} 배열이 추가로 붙는다.
 */
@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {

    /** 기본값이라 Spring 이 생략하므로, 양식을 지키기 위해 명시적으로 세팅한다. */
    private static final URI BLANK_TYPE = URI.create("about:blank");

    private static final DateTimeFormatter TIMESTAMP_FORMAT =
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
    private static final ZoneId ZONE = ZoneId.of("Asia/Seoul");

    /** 비즈니스 규칙 위반. 의도된 예외이므로 스택트레이스 없이 warn 으로만 남긴다. */
    @ExceptionHandler(BusinessException.class)
    public ProblemDetail handleBusinessException(BusinessException e) {
        BaseErrorCode errorCode = e.getErrorCode();
        log.warn("BusinessException: errorCode={}, message={}", errorCode.name(), e.getMessage());

        return problemDetail(errorCode.getStatus(), e.getMessage(), e);
    }

    /** {@code @Valid} 검증 실패. 어느 필드가 왜 틀렸는지 errors 확장 속성으로 함께 내려준다. */
    @Override
    protected ResponseEntity<Object> handleMethodArgumentNotValid(MethodArgumentNotValidException e,
                                                                  HttpHeaders headers,
                                                                  HttpStatusCode status,
                                                                  WebRequest request) {
        log.warn("Validation failed: {}", e.getMessage());

        ErrorCode errorCode = ErrorCode.INVALID_INPUT_VALUE;
        ProblemDetail body = problemDetail(errorCode.getStatus(), errorCode.getMessage(), e);
        List<FieldError> errors = e.getBindingResult().getFieldErrors().stream()
                .map(error -> new FieldError(error.getField(), error.getDefaultMessage()))
                .toList();
        body.setProperty("errors", errors);

        return handleExceptionInternal(e, body, headers, status, request);
    }

    /** 처리되지 않은 예외. 내부 정보가 노출되지 않도록 고정 메시지만 응답하고 원인은 로그로 남긴다. */
    @ExceptionHandler(Exception.class)
    public ProblemDetail handleException(Exception e) {
        log.error("Unhandled exception", e);

        ErrorCode errorCode = ErrorCode.INTERNAL_SERVER_ERROR;
        return problemDetail(errorCode.getStatus(), errorCode.getMessage(), e);
    }

    /** 우리가 직접 잡지 않은 Spring 내장 예외의 응답도 같은 확장 속성을 갖도록 보정한다. */
    @Override
    protected ResponseEntity<Object> handleExceptionInternal(Exception e,
                                                             Object body,
                                                             HttpHeaders headers,
                                                             HttpStatusCode statusCode,
                                                             WebRequest request) {
        ResponseEntity<Object> response = super.handleExceptionInternal(e, body, headers, statusCode, request);

        if (response != null && response.getBody() instanceof ProblemDetail problemDetail) {
            decorate(problemDetail, e);
        }

        return response;
    }

    private ProblemDetail problemDetail(HttpStatusCode status, String errorMessage, Exception e) {
        ProblemDetail problemDetail = ProblemDetail.forStatus(status);
        problemDetail.setType(BLANK_TYPE);
        problemDetail.setProperty("errorMessage", errorMessage);
        problemDetail.setProperty("timestamp", now());
        problemDetail.setProperty("exception", e.getClass().getSimpleName());

        return problemDetail;
    }

    /** 이미 우리 포맷으로 만들어진 응답은 건드리지 않는다. */
    private void decorate(ProblemDetail problemDetail, Exception e) {
        Map<String, Object> properties = problemDetail.getProperties();
        if (properties != null && properties.containsKey("errorMessage")) {
            return;
        }

        problemDetail.setType(BLANK_TYPE);
        // 메시지 필드를 errorMessage 로 통일하고 표준 detail 은 비운다.
        problemDetail.setProperty("errorMessage", problemDetail.getDetail());
        problemDetail.setDetail(null);
        problemDetail.setProperty("timestamp", now());
        problemDetail.setProperty("exception", e.getClass().getSimpleName());
    }

    private String now() {
        return LocalDateTime.now(ZONE).format(TIMESTAMP_FORMAT);
    }

    public record FieldError(String field, String reason) {
    }
}
