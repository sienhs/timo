package com.ssafy.timo.global.security;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jwt.Jwt;

/**
 * 만료를 다른 검증 실패와 구분해 표시하는지 검증한다.
 *
 * <p>스프링 컨텍스트를 띄우지 않는다. 이 판정이 뒤집히면 앱이 만료 때마다 로그아웃되거나
 * 반대로 재발급 루프에 빠지는데, 그런 회귀를 통합 테스트 환경과 무관하게 잡아야 한다.
 */
class ExpiryAwareJwtValidatorTest {

    private static final Instant NOW = Instant.parse("2026-09-08T00:00:00Z");
    private static final Clock FIXED_CLOCK = Clock.fixed(NOW, ZoneOffset.UTC);

    /** 실제 사유는 무엇이든 상관없다. 검증기가 실패를 냈다는 사실만 필요하다. */
    private static final OAuth2Error SOME_FAILURE =
            new OAuth2Error("invalid_token", "some validation failed", null);

    @Test
    @DisplayName("검증을 통과하면 성공을 그대로 돌려준다")
    void success_isPassedThrough() {
        ExpiryAwareJwtValidator validator = validatorWith(OAuth2TokenValidatorResult.success());

        OAuth2TokenValidatorResult result = validator.validate(jwtExpiringAt(NOW.plusSeconds(600)));

        assertThat(result.hasErrors()).isFalse();
    }

    @Test
    @DisplayName("만료가 유일한 실패 사유면 만료 에러 코드로 바꿔 준다")
    void expired_isMarkedWithExpiredErrorCode() {
        ExpiryAwareJwtValidator validator = validatorWith(OAuth2TokenValidatorResult.failure(SOME_FAILURE));

        OAuth2TokenValidatorResult result = validator.validate(jwtExpiringAt(NOW.minusSeconds(3600)));

        assertThat(result.getErrors())
                .extracting(OAuth2Error::getErrorCode)
                .containsExactly(ExpiryAwareJwtValidator.TOKEN_EXPIRED_ERROR_CODE);
    }

    @Test
    @DisplayName("아직 만료되지 않았는데 실패했다면 원래 사유를 그대로 둔다")
    void notExpired_keepsOriginalError() {
        ExpiryAwareJwtValidator validator = validatorWith(OAuth2TokenValidatorResult.failure(SOME_FAILURE));

        OAuth2TokenValidatorResult result = validator.validate(jwtExpiringAt(NOW.plusSeconds(600)));

        assertThat(result.getErrors())
                .extracting(OAuth2Error::getErrorCode)
                .containsExactly(SOME_FAILURE.getErrorCode());
    }

    @Test
    @DisplayName("허용 오차(60초) 안에서는 아직 만료로 보지 않는다")
    void withinClockSkew_isNotTreatedAsExpired() {
        ExpiryAwareJwtValidator validator = validatorWith(OAuth2TokenValidatorResult.failure(SOME_FAILURE));

        OAuth2TokenValidatorResult result = validator.validate(jwtExpiringAt(NOW.minusSeconds(30)));

        assertThat(result.getErrors())
                .extracting(OAuth2Error::getErrorCode)
                .containsExactly(SOME_FAILURE.getErrorCode());
    }

    @Test
    @DisplayName("만료 말고 다른 문제도 함께 있으면 만료로 표시하지 않는다")
    void multipleFailures_keepOriginalErrors() {
        OAuth2Error anotherFailure = new OAuth2Error("invalid_token", "issuer mismatch", null);
        ExpiryAwareJwtValidator validator =
                validatorWith(OAuth2TokenValidatorResult.failure(SOME_FAILURE, anotherFailure));

        OAuth2TokenValidatorResult result = validator.validate(jwtExpiringAt(NOW.minusSeconds(3600)));

        // 재발급으로 풀리지 않을 수 있는 토큰이므로 재발급을 유도하면 안 된다.
        assertThat(result.getErrors())
                .extracting(OAuth2Error::getErrorCode)
                .doesNotContain(ExpiryAwareJwtValidator.TOKEN_EXPIRED_ERROR_CODE);
    }

    @Test
    @DisplayName("exp 가 없는 토큰은 만료로 표시하지 않는다")
    void missingExpiry_isNotTreatedAsExpired() {
        ExpiryAwareJwtValidator validator = validatorWith(OAuth2TokenValidatorResult.failure(SOME_FAILURE));

        OAuth2TokenValidatorResult result = validator.validate(jwtExpiringAt(null));

        assertThat(result.getErrors())
                .extracting(OAuth2Error::getErrorCode)
                .containsExactly(SOME_FAILURE.getErrorCode());
    }

    private ExpiryAwareJwtValidator validatorWith(OAuth2TokenValidatorResult delegateResult) {
        OAuth2TokenValidator<Jwt> delegate = jwt -> delegateResult;
        return new ExpiryAwareJwtValidator(delegate, FIXED_CLOCK);
    }

    private Jwt jwtExpiringAt(Instant expiresAt) {
        Jwt.Builder builder = Jwt.withTokenValue("token")
                .header("alg", "HS256")
                .subject("1")
                .claim("roles", List.of("USER"))
                .issuedAt(NOW.minusSeconds(7200));

        if (expiresAt != null) {
            builder.expiresAt(expiresAt);
        }

        return builder.build();
    }
}
