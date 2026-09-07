package com.ssafy.timo.global.security;

import com.ssafy.timo.global.exception.BusinessException;
import com.ssafy.timo.global.security.exception.ForbiddenException;
import com.ssafy.timo.global.security.exception.TokenExpiredException;
import com.ssafy.timo.global.security.exception.TokenInvalidException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.http.HttpHeaders;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.oauth2.jwt.JwtValidationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerExceptionResolver;
// BE 패키지 컨벤션 적용 X - security  
@Slf4j
@Component
public class AuthExceptionHandler implements AuthenticationEntryPoint, AccessDeniedHandler {

    private final HandlerExceptionResolver handlerExceptionResolver;

    public AuthExceptionHandler(
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
        resolve(request, response, exception);
    }

    @Override
    public void handle(HttpServletRequest request,
                       HttpServletResponse response,
                       AccessDeniedException accessDeniedException) throws IOException {

        log.warn("Access denied: method={}, uri={}, reason={}",
                request.getMethod(), request.getRequestURI(), accessDeniedException.getMessage());

        resolve(request, response, new ForbiddenException());
    }

    private boolean isExpired(AuthenticationException authenticationException) {
        for (Throwable cause = authenticationException.getCause(); cause != null; cause = cause.getCause()) {
            if (cause instanceof JwtValidationException) {
                return true;
            }
        }
        return false;
    }

    private void resolve(HttpServletRequest request,
                         HttpServletResponse response,
                         BusinessException exception) throws IOException {

        if (handlerExceptionResolver.resolveException(request, response, null, exception) == null) {
            log.error("Failed to resolve security exception, falling back to sendError: exception={}",
                    exception.getClass().getSimpleName());
            response.sendError(exception.getErrorCode().getStatus().value());
        }
    }
}
