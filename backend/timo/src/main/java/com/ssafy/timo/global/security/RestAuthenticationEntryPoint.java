package com.ssafy.timo.global.security;

import com.ssafy.timo.global.exception.BusinessException;
import com.ssafy.timo.global.security.exception.TokenExpiredException;
import com.ssafy.timo.global.security.exception.TokenInvalidException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.http.HttpHeaders;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.oauth2.jwt.JwtValidationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerExceptionResolver;

@Slf4j
@Component
public class RestAuthenticationEntryPoint implements AuthenticationEntryPoint {

    private final HandlerExceptionResolver handlerExceptionResolver;

    public RestAuthenticationEntryPoint(
            @Qualifier("handlerExceptionResolver") HandlerExceptionResolver handlerExceptionResolver) {
        this.handlerExceptionResolver = handlerExceptionResolver;
    }

    @Override
    public void commence(HttpServletRequest request,
                         HttpServletResponse response,
                         AuthenticationException authenticationException) throws IOException {

        BusinessException exception = isExpired(authenticationException)
                ? new TokenExpiredException()
                : new TokenInvalidException();

        log.warn("Authentication failed: exception={}, method={}, uri={}, reason={}",
                exception.getClass().getSimpleName(), request.getMethod(), request.getRequestURI(),
                authenticationException.getMessage());

        response.setHeader(HttpHeaders.WWW_AUTHENTICATE, "Bearer");

        if (handlerExceptionResolver.resolveException(request, response, null, exception) == null) {
            log.error("Failed to resolve authentication exception, falling back to sendError");
            response.sendError(exception.getErrorCode().getStatus().value());
        }
    }

    /**
     * 만료 때문에 실패한 것인지 판별한다.
     *
     * <p>{@code JwtValidationException} 이라는 사실만으로는 부족하다. 만료뿐 아니라 nbf 위반,
     * 나중에 추가될 발급자·대상 검증 실패도 전부 같은 타입이기 때문이다. 그것들까지 만료로
     * 취급하면 앱이 재발급을 시도하고 새 토큰도 같은 이유로 막혀 무한 루프가 된다.
     *
     * <p>그래서 {@link ExpiryAwareJwtValidator} 가 만료일 때만 남겨 둔 에러 코드를 확인한다.
     * 사람이 읽으라고 만든 메시지를 문자열 비교하지 않는다.
     */
    private boolean isExpired(AuthenticationException authenticationException) {
        for (Throwable cause = authenticationException.getCause();
                cause != null && cause != cause.getCause();
                cause = cause.getCause()) {

            if (cause instanceof JwtValidationException validationException) {
                return hasExpiredError(validationException);
            }
        }
        return false;
    }

    private boolean hasExpiredError(JwtValidationException validationException) {
        return validationException.getErrors().stream()
                .anyMatch(error ->
                        ExpiryAwareJwtValidator.TOKEN_EXPIRED_ERROR_CODE.equals(error.getErrorCode()));
    }
}
