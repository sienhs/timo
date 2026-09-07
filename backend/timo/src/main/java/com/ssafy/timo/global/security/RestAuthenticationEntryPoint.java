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

    private boolean isExpired(AuthenticationException authenticationException) {
        for (Throwable cause = authenticationException.getCause(); cause != null; cause = cause.getCause()) {
            if (cause instanceof JwtValidationException) {
                return true;
            }
        }
        return false;
    }
}
