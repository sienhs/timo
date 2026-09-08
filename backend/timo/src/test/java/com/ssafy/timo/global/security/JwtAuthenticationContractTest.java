package com.ssafy.timo.global.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.catchThrowableOfType;

import com.nimbusds.jose.JOSEObjectType;
import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.crypto.MACSigner;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import com.ssafy.timo.global.config.JwtConfig;
import com.ssafy.timo.global.config.JwtProperties;
import com.ssafy.timo.global.security.exception.TokenExpiredException;
import com.ssafy.timo.global.security.exception.TokenInvalidException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.core.convert.converter.Converter;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.AbstractAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.server.resource.authentication.BearerTokenAuthenticationToken;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationProvider;
import org.springframework.web.servlet.HandlerExceptionResolver;
import org.springframework.web.servlet.ModelAndView;

/**
 * 실제 토큰이 필터 체인을 탔을 때 어떤 에러 코드로 나가는지 못 박는다.
 *
 * <p>{@link JwtConfig} 가 만드는 진짜 디코더·컨버터에 진짜 서명 토큰을 넣고,
 * Spring Security 가 던진 예외를 {@link RestAuthenticationEntryPoint} 에 그대로 넘긴다.
 * 단위 테스트에서 예외를 손으로 만들면 스프링이 실제로 던지는 모양과 어긋날 수 있는데,
 * 그 어긋남이 바로 만료 판정이 조용히 뒤집히는 경로다.
 *
 * <p>스프링 컨텍스트는 띄우지 않는다. 통합 테스트 환경(DB·Redis)과 무관하게 항상 돌아야 한다.
 */
class JwtAuthenticationContractTest {

    /** application-local.yml / application-test.yml 과 같은 값. HS256 이라 32바이트 이상이어야 한다. */
    private static final String SECRET = "local-dev-only-secret-please-change-in-prod-0123456789";

    private final JwtConfig jwtConfig = new JwtConfig(new JwtProperties(SECRET, null));
    private final JwtDecoder jwtDecoder = jwtConfig.jwtDecoder();
    private final Converter<Jwt, ? extends AbstractAuthenticationToken> jwtAuthenticationConverter =
            jwtConfig.jwtAuthenticationConverter();

    private final CapturingExceptionResolver resolver = new CapturingExceptionResolver();
    private final RestAuthenticationEntryPoint entryPoint = new RestAuthenticationEntryPoint(resolver);

    @Test
    @DisplayName("유효한 토큰은 인증에 성공하고 roles 클레임이 ROLE_ 권한이 된다")
    void validToken_authenticates() throws Exception {
        Authentication authentication = authenticate(signedToken(Duration.ofMinutes(30)));

        assertThat(authentication.getName()).isEqualTo("1");
        // Spring Security 7 이 인증 수단을 나타내는 FACTOR_BEARER 를 함께 넣어 준다.
        // 우리 관심사는 roles 클레임이 SCOPE_ 가 아니라 ROLE_ 로 변환됐는지다.
        assertThat(authentication.getAuthorities())
                .extracting(GrantedAuthority::getAuthority)
                .contains("ROLE_USER");
    }

    @Test
    @DisplayName("만료된 토큰은 TOKEN_EXPIRED 로 나간다 (앱이 재발급 후 재시도해야 하는 경우)")
    void expiredToken_yieldsTokenExpired() throws Exception {
        translate(signedToken(Duration.ofMinutes(-30)));

        assertThat(resolver.captured).isInstanceOf(TokenExpiredException.class);
    }

    @Test
    @DisplayName("서명이 다른 토큰은 TOKEN_INVALID 로 나간다 (재발급 없이 로그아웃해야 하는 경우)")
    void wrongSignature_yieldsTokenInvalid() throws Exception {
        String forged = signedToken(Duration.ofMinutes(30), "another-secret-key-that-is-long-enough-0123456789");

        translate(forged);

        assertThat(resolver.captured).isInstanceOf(TokenInvalidException.class);
    }

    @Test
    @DisplayName("JWT 형식이 아니면 TOKEN_INVALID 로 나간다")
    void malformedToken_yieldsTokenInvalid() throws Exception {
        translate("not-a-jwt");

        assertThat(resolver.captured).isInstanceOf(TokenInvalidException.class);
    }

    private Authentication authenticate(String token) {
        JwtAuthenticationProvider provider = new JwtAuthenticationProvider(jwtDecoder);
        provider.setJwtAuthenticationConverter(jwtAuthenticationConverter);

        return provider.authenticate(new BearerTokenAuthenticationToken(token));
    }

    /** 인증 실패를 EntryPoint 까지 흘려보내, 실제로 어떤 에러 코드로 번역되는지 본다. */
    private void translate(String token) throws Exception {
        AuthenticationException failure =
                catchThrowableOfType(AuthenticationException.class, () -> authenticate(token));
        assertThat(failure).as("인증이 실패해야 하는 토큰인데 통과했다").isNotNull();

        entryPoint.commence(new MockHttpServletRequest("GET", "/api/v1/venues/1"),
                new MockHttpServletResponse(), failure);
    }

    private String signedToken(Duration validFor) throws Exception {
        return signedToken(validFor, SECRET);
    }

    private String signedToken(Duration validFor, String secret) throws Exception {
        Instant issuedAt = Instant.now().minus(Duration.ofHours(1));
        Instant expiresAt = Instant.now().plus(validFor);

        JWTClaimsSet claims = new JWTClaimsSet.Builder()
                .subject("1")
                .claim("roles", List.of("USER"))
                .issueTime(Date.from(issuedAt))
                .expirationTime(Date.from(expiresAt))
                .build();

        SignedJWT jwt = new SignedJWT(
                new JWSHeader.Builder(JWSAlgorithm.HS256).type(JOSEObjectType.JWT).build(), claims);
        jwt.sign(new MACSigner(secret.getBytes(StandardCharsets.UTF_8)));

        return jwt.serialize();
    }

    private static final class CapturingExceptionResolver implements HandlerExceptionResolver {

        private Exception captured;

        @Override
        public ModelAndView resolveException(HttpServletRequest request,
                                             HttpServletResponse response,
                                             Object handler,
                                             Exception ex) {
            this.captured = ex;
            return new ModelAndView();
        }
    }
}
