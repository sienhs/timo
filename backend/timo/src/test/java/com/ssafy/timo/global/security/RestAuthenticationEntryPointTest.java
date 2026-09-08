package com.ssafy.timo.global.security;

import static org.assertj.core.api.Assertions.assertThat;

import com.ssafy.timo.global.security.exception.AuthErrorCode;
import com.ssafy.timo.global.security.exception.AuthException;
import com.ssafy.timo.global.security.exception.TokenExpiredException;
import com.ssafy.timo.global.security.exception.TokenInvalidException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.InsufficientAuthenticationException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.jwt.BadJwtException;
import org.springframework.security.oauth2.jwt.JwtValidationException;
import org.springframework.security.oauth2.server.resource.InvalidBearerTokenException;
import org.springframework.web.servlet.HandlerExceptionResolver;
import org.springframework.web.servlet.ModelAndView;

/**
 * 인증 실패를 어떤 예외로 번역하는지 검증한다.
 *
 * <p>이 판정이 앱의 동작을 가른다. {@code TOKEN_EXPIRED} 면 재발급 후 재시도,
 * {@code TOKEN_INVALID} 면 재발급 없이 즉시 로그아웃이다. 잘못 뒤집히면
 * 만료마다 강제 로그아웃되거나 반대로 무한 재발급 루프가 된다.
 *
 * <p>스프링 컨텍스트 없이 돌아간다. 예외 해석기는 무엇이 넘어왔는지만 기록하는 스텁을 쓴다.
 */
class RestAuthenticationEntryPointTest {

    private final CapturingExceptionResolver resolver = new CapturingExceptionResolver();
    private final RestAuthenticationEntryPoint entryPoint = new RestAuthenticationEntryPoint(resolver);

    @Test
    @DisplayName("만료 에러 코드가 실려 오면 TOKEN_EXPIRED 로 번역한다")
    void expiredToken_becomesTokenExpired() throws Exception {
        commence(bearerTokenFailure(new JwtValidationException("expired", List.of(
                new OAuth2Error(ExpiryAwareJwtValidator.TOKEN_EXPIRED_ERROR_CODE, "Jwt expired at ...", null)))));

        assertThat(resolver.captured).isInstanceOf(TokenExpiredException.class);
        assertThat(((AuthException) resolver.captured).getErrorCode()).isEqualTo(AuthErrorCode.TOKEN_EXPIRED);
    }

    @Test
    @DisplayName("만료가 아닌 검증 실패는 TOKEN_INVALID 로 번역한다")
    void otherValidationFailure_becomesTokenInvalid() throws Exception {
        // 발급자·대상 검증을 추가하면 이 모양으로 온다. 재발급해도 풀리지 않으므로 로그아웃이어야 한다.
        commence(bearerTokenFailure(new JwtValidationException("issuer mismatch", List.of(
                new OAuth2Error("invalid_token", "The iss claim is not valid", null)))));

        assertThat(resolver.captured).isInstanceOf(TokenInvalidException.class);
    }

    @Test
    @DisplayName("서명이 깨졌거나 형식이 틀린 토큰은 TOKEN_INVALID 로 번역한다")
    void malformedToken_becomesTokenInvalid() throws Exception {
        commence(bearerTokenFailure(new BadJwtException("Signed JWT rejected: Invalid signature")));

        assertThat(resolver.captured).isInstanceOf(TokenInvalidException.class);
    }

    @Test
    @DisplayName("토큰이 아예 없으면 TOKEN_INVALID 로 번역한다")
    void missingToken_becomesTokenInvalid() throws Exception {
        commence(new InsufficientAuthenticationException("Full authentication is required"));

        assertThat(resolver.captured).isInstanceOf(TokenInvalidException.class);
    }

    @Test
    @DisplayName("RFC 6750 에 따라 WWW-Authenticate 헤더를 남긴다")
    void setsWwwAuthenticateHeader() throws Exception {
        MockHttpServletResponse response = commence(new InsufficientAuthenticationException("no token"));

        assertThat(response.getHeader(HttpHeaders.WWW_AUTHENTICATE)).isEqualTo("Bearer");
    }

    @Test
    @DisplayName("예외 해석기가 처리하지 못하면 상태 코드라도 401 로 내려보낸다")
    void fallsBackToSendErrorWhenUnresolved() throws Exception {
        CapturingExceptionResolver unresolving = new CapturingExceptionResolver();
        unresolving.resolve = false;

        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/venues/1");
        MockHttpServletResponse response = new MockHttpServletResponse();
        new RestAuthenticationEntryPoint(unresolving)
                .commence(request, response, new InsufficientAuthenticationException("no token"));

        assertThat(response.getStatus()).isEqualTo(AuthErrorCode.TOKEN_INVALID.getStatus().value());
    }

    private MockHttpServletResponse commence(AuthenticationException exception) throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/venues/1");
        MockHttpServletResponse response = new MockHttpServletResponse();

        entryPoint.commence(request, response, exception);

        return response;
    }

    /** {@code JwtAuthenticationProvider} 가 실제로 만들어 내는 예외 모양이다. */
    private AuthenticationException bearerTokenFailure(Throwable cause) {
        return new InvalidBearerTokenException(cause.getMessage(), cause);
    }

    private static final class CapturingExceptionResolver implements HandlerExceptionResolver {

        private Exception captured;
        private boolean resolve = true;

        @Override
        public ModelAndView resolveException(HttpServletRequest request,
                                             HttpServletResponse response,
                                             Object handler,
                                             Exception ex) {
            this.captured = ex;
            return resolve ? new ModelAndView() : null;
        }
    }
}
