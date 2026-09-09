package com.ssafy.timo.global.exception;

import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.validation.method.ParameterErrors;
import org.springframework.validation.method.ParameterValidationResult;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.method.annotation.HandlerMethodValidationException;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;

import tools.jackson.core.JacksonException;
import tools.jackson.databind.exc.InvalidFormatException;
import tools.jackson.databind.exc.MismatchedInputException;

import java.net.URI;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

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
 * <p>어느 필드가 왜 틀렸는지 알 수 있을 때 {@code errors} 배열이 추가로 붙는다.
 * {@code @Valid} 검증 실패가 대표적이고, enum 오타나 날짜 형식 오류처럼 본문 매핑 단계에서
 * 실패한 경우에도 Jackson 이 알려주는 경로를 같은 모양으로 실어 보낸다.
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

    /**
     * 메서드 파라미터 검증 실패. {@code @RequestHeader} 같은 파라미터에 제약이 붙은 메서드에서
     * {@code @Valid @RequestBody} 검증이 실패하면 {@link MethodArgumentNotValidException} 이 아니라
     * 이쪽으로 온다. 스프링 6.1 부터 그런 메서드는 파라미터 검증 경로를 타기 때문이다.
     *
     * <p>재정의하지 않으면 어느 필드가 왜 틀렸는지가 빠진 응답이 나가 <b>같은 검증 실패인데
     * 메서드 시그니처에 따라 응답 모양이 갈린다.</b> {@code @Valid} 실패와 같은 {@code errors} 배열로 맞춘다.
     */
    @Override
    protected ResponseEntity<Object> handleHandlerMethodValidationException(HandlerMethodValidationException e,
                                                                           HttpHeaders headers,
                                                                           HttpStatusCode status,
                                                                           WebRequest request) {
        log.warn("Validation failed: {}", e.getMessage());

        ErrorCode errorCode = ErrorCode.INVALID_INPUT_VALUE;
        ProblemDetail body = problemDetail(errorCode.getStatus(), errorCode.getMessage(), e);
        body.setProperty("errors", toFieldErrors(e));

        return handleExceptionInternal(e, body, headers, status, request);
    }

    /**
     * 본문 안쪽 필드 오류({@code ParameterErrors})는 필드명이 있고, 파라미터 자체의 오류
     * ({@code X-Device-Id} 같은)는 파라미터명을 대신 쓴다.
     */
    private List<FieldError> toFieldErrors(HandlerMethodValidationException e) {
        List<FieldError> errors = new ArrayList<>();

        for (ParameterValidationResult result : e.getParameterValidationResults()) {
            if (result instanceof ParameterErrors parameterErrors) {
                parameterErrors.getFieldErrors().forEach(fieldError ->
                        errors.add(new FieldError(fieldError.getField(), fieldError.getDefaultMessage())));
                continue;
            }

            String name = result.getMethodParameter().getParameterName();
            result.getResolvableErrors().forEach(resolvable ->
                    errors.add(new FieldError(name, resolvable.getDefaultMessage())));
        }

        return errors;
    }

    /**
     * 본문을 읽지 못한 경우. enum 오타나 날짜 형식 오류처럼 Jackson 이 값을 매핑하지 못하면
     * 여기로 오는데, 기본 응답은 어느 필드가 문제인지 알려주지 않는다.
     * 그래서 Jackson 이 들고 있는 경로 정보를 꺼내 {@code @Valid} 실패와 같은 모양의
     * {@code errors} 배열로 만들어 준다. 경로를 알 수 없는 경우(깨진 JSON 등)에는 붙이지 않는다.
     */
    @Override
    protected ResponseEntity<Object> handleHttpMessageNotReadable(HttpMessageNotReadableException e,
                                                                  HttpHeaders headers,
                                                                  HttpStatusCode status,
                                                                  WebRequest request) {
        log.warn("Request body not readable: {}", e.getMessage());

        ErrorCode errorCode = ErrorCode.INVALID_INPUT_VALUE;
        ProblemDetail body = problemDetail(errorCode.getStatus(), errorCode.getMessage(), e);
        toFieldError(e.getCause()).ifPresent(fieldError -> body.setProperty("errors", List.of(fieldError)));

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

    /** Jackson 매핑 실패에서 문제가 된 필드와 사유를 뽑아낸다. 경로를 알 수 없으면 비어 있다. */
    private Optional<FieldError> toFieldError(Throwable cause) {
        if (!(cause instanceof MismatchedInputException mismatch)) {
            return Optional.empty();
        }

        String field = toFieldPath(mismatch.getPath());
        if (field.isEmpty()) {
            return Optional.empty();
        }

        return Optional.of(new FieldError(field, toReason(mismatch)));
    }

    /** 중첩 객체와 배열을 {@code artistIds[1]}, {@code venue.name} 처럼 이어 붙인다. */
    private String toFieldPath(List<JacksonException.Reference> references) {
        StringBuilder path = new StringBuilder();

        for (JacksonException.Reference reference : references) {
            if (reference.getPropertyName() != null) {
                if (!path.isEmpty()) {
                    path.append('.');
                }
                path.append(reference.getPropertyName());
            } else if (reference.getIndex() >= 0) {
                path.append('[').append(reference.getIndex()).append(']');
            }
        }

        return path.toString();
    }

    /**
     * enum 은 허용되는 값을 함께 알려준다. 상수명은 API 규약의 일부라 노출해도 되는 정보다.
     * 그 밖의 타입은 내부 클래스명이 새지 않도록 고정 문구만 쓴다.
     */
    private String toReason(MismatchedInputException e) {
        Class<?> targetType = e.getTargetType();

        if (targetType != null && targetType.isEnum()) {
            String allowed = Arrays.stream(targetType.getEnumConstants())
                    .map(String::valueOf)
                    .collect(Collectors.joining(", "));
            String rejected = e instanceof InvalidFormatException invalid
                    ? String.valueOf(invalid.getValue())
                    : "";

            return "허용되지 않는 값입니다: %s (가능한 값: %s)".formatted(rejected, allowed);
        }

        return "값의 형식이 올바르지 않습니다.";
    }

    private String now() {
        return LocalDateTime.now(ZONE).format(TIMESTAMP_FORMAT);
    }

    public record FieldError(String field, String reason) {
    }
}
