package com.ssafy.timo.global.security;

import com.ssafy.timo.global.security.exception.ForbiddenException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerExceptionResolver;

@Slf4j
@Component
public class RestAccessDeniedHandler implements AccessDeniedHandler {

    private final HandlerExceptionResolver handlerExceptionResolver;

    public RestAccessDeniedHandler(
            @Qualifier("handlerExceptionResolver") HandlerExceptionResolver handlerExceptionResolver) {
        this.handlerExceptionResolver = handlerExceptionResolver;
    }

    @Override
    public void handle(HttpServletRequest request,
                       HttpServletResponse response,
                       AccessDeniedException accessDeniedException) throws IOException {

        log.warn("Access denied: method={}, uri={}, reason={}",
                request.getMethod(), request.getRequestURI(), accessDeniedException.getMessage());

        ForbiddenException exception = new ForbiddenException();

        if (handlerExceptionResolver.resolveException(request, response, null, exception) == null) {
            log.error("Failed to resolve access denied exception, falling back to sendError");
            response.sendError(exception.getErrorCode().getStatus().value());
        }
    }
}
