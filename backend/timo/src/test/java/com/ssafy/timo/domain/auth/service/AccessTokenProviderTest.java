package com.ssafy.timo.domain.auth.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.ssafy.timo.domain.auth.service.AccessTokenProvider.AccessToken;
import com.ssafy.timo.domain.member.entity.Role;
import com.ssafy.timo.global.config.JwtConfig;
import com.ssafy.timo.global.config.JwtProperties;
import java.time.Duration;
import java.time.temporal.ChronoUnit;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;

/**
 * access token 발급을 검증한다.
 *
 * <p>{@link JwtConfig} 가 만드는 실제 인코더·디코더를 그대로 쓴다. 발급한 토큰을 우리 디코더가
 * 다시 풀 수 있는지까지 봐야 "발급은 되는데 검증에서 막히는" 상태를 잡을 수 있다.
 *
 * <p>스프링 컨텍스트는 띄우지 않는다.
 */
class AccessTokenProviderTest {

    private static final String SECRET = "local-dev-only-secret-please-change-in-prod-0123456789";
    private static final Duration TTL = Duration.ofMinutes(30);
    private static final long MEMBER_ID = 42L;

    private final JwtProperties jwtProperties = new JwtProperties(SECRET, TTL);
    private final JwtConfig jwtConfig = new JwtConfig(jwtProperties);
    private final JwtDecoder jwtDecoder = jwtConfig.jwtDecoder();
    private final AccessTokenProvider accessTokenProvider =
            new AccessTokenProvider(jwtConfig.jwtEncoder(), jwtProperties);

    @Test
    @DisplayName("발급한 토큰은 우리 디코더로 다시 풀린다")
    void issuedToken_isDecodable() {
        AccessToken accessToken = accessTokenProvider.issue(MEMBER_ID, Role.USER);

        Jwt jwt = jwtDecoder.decode(accessToken.value());

        assertThat(jwt.getSubject()).isEqualTo("42");
        assertThat(jwt.getClaimAsStringList("roles")).containsExactly("USER");
    }

    @Test
    @DisplayName("설정한 수명만큼만 유효하고, 남은 수명을 함께 알려준다")
    void issuedToken_expiresAfterConfiguredTtl() {
        AccessToken accessToken = accessTokenProvider.issue(MEMBER_ID, Role.USER);

        Jwt jwt = jwtDecoder.decode(accessToken.value());

        assertThat(accessToken.expiresInSeconds()).isEqualTo(TTL.toSeconds());
        assertThat(Duration.between(jwt.getIssuedAt(), jwt.getExpiresAt()).toSeconds())
                .isEqualTo(TTL.toSeconds());
    }

    @Test
    @DisplayName("개인정보는 담지 않는다")
    void issuedToken_carriesNoPersonalData() {
        AccessToken accessToken = accessTokenProvider.issue(MEMBER_ID, Role.USER);

        Jwt jwt = jwtDecoder.decode(accessToken.value());

        // JWT 는 서명일 뿐 암호화가 아니라 본문을 누구나 읽는다. 클레임이 늘어나는 걸
        // 막기 위해 허용 목록을 통째로 고정한다. 새 클레임을 넣으려면 여기서 한 번 걸린다.
        assertThat(jwt.getClaims()).containsOnlyKeys("sub", "roles", "iat", "exp", "jti");
    }

    @Test
    @DisplayName("토큰마다 다른 식별자(jti)를 붙인다")
    void issuedTokens_haveDistinctIds() {
        String first = jwtDecoder.decode(accessTokenProvider.issue(MEMBER_ID, Role.USER).value()).getId();
        String second = jwtDecoder.decode(accessTokenProvider.issue(MEMBER_ID, Role.USER).value()).getId();

        assertThat(first).isNotNull().isNotEqualTo(second);
    }

    @Test
    @DisplayName("권한은 회원의 역할을 그대로 싣는다")
    void issuedToken_carriesGivenRole() {
        AccessToken accessToken = accessTokenProvider.issue(MEMBER_ID, Role.ADMIN);

        assertThat(jwtDecoder.decode(accessToken.value()).getClaimAsStringList("roles"))
                .containsExactly("ADMIN");
    }

    @Test
    @DisplayName("수명을 설정하지 않으면 30분을 쓴다")
    void ttl_defaultsToThirtyMinutes() {
        assertThat(new JwtProperties(SECRET, null).accessTokenTtl())
                .isEqualTo(Duration.of(30, ChronoUnit.MINUTES));
    }

    @Test
    @DisplayName("비밀키가 32바이트보다 짧으면 기동 시점에 막는다")
    void shortSecret_failsFast() {
        assertThatThrownBy(() -> new JwtProperties("too-short", TTL))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("jwt.secret");
    }
}
