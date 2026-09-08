package com.ssafy.timo.global.security;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtValidators;

/**
 * 토큰 만료를 다른 검증 실패와 구분할 수 있게 표시해 주는 검증기.
 *
 * <p>왜 필요한가. 검증에 실패하면 Spring Security 는 사유가 무엇이든 {@code JwtValidationException}
 * 하나로 묶어 던진다. 만료({@code exp})도, 아직 유효하지 않음({@code nbf})도, 나중에 발급자
 * ({@code iss})·대상({@code aud}) 검증을 추가하면 그것도 전부 같은 타입이다. 그래서 예외 타입만
 * 보고 "만료"라고 판단하면, issuer 가 틀린 토큰까지 만료로 취급된다. 그러면 앱은 재발급을 시도하고,
 * 새로 받은 토큰도 issuer 가 틀리므로 다시 실패한다. <b>무한 재발급 루프</b>다.
 *
 * <p>그래서 만료일 때만 {@link #TOKEN_EXPIRED_ERROR_CODE} 라는 우리 에러 코드로 갈아 끼운다.
 * 이 코드는 {@code JwtValidationException.getErrors()} 에 그대로 실려 오므로
 * {@link RestAuthenticationEntryPoint} 가 사람이 읽는 메시지를 문자열 비교하지 않고 판별할 수 있다.
 *
 * <p>실패 사유가 둘 이상이면 갈아 끼우지 않는다. 만료 외의 문제가 함께 있는 토큰은 재발급으로
 * 해결되지 않을 수 있어, 재발급을 유도하는 것보다 로그아웃시키는 편이 안전하다.
 *
 * <p>기본 검증({@link JwtValidators#createDefault()})은 그대로 위임한다. 나중에 발급자·대상 검증을
 * 추가하더라도 이 클래스는 손대지 않는다.
 */
public final class ExpiryAwareJwtValidator implements OAuth2TokenValidator<Jwt> {

    /** 만료를 나타내는 우리 에러 코드. 표준 코드가 아니라 우리끼리 쓰는 식별자다. */
    public static final String TOKEN_EXPIRED_ERROR_CODE = "token_expired";

    /** {@code JwtTimestampValidator} 의 기본값과 같게 맞춘다. 다르면 판정이 어긋난다. */
    private static final Duration CLOCK_SKEW = Duration.ofSeconds(60);

    private final OAuth2TokenValidator<Jwt> delegate;
    private final Clock clock;

    public ExpiryAwareJwtValidator() {
        this(JwtValidators.createDefault(), Clock.systemUTC());
    }

    ExpiryAwareJwtValidator(OAuth2TokenValidator<Jwt> delegate, Clock clock) {
        this.delegate = delegate;
        this.clock = clock;
    }

    @Override
    public OAuth2TokenValidatorResult validate(Jwt jwt) {
        OAuth2TokenValidatorResult result = delegate.validate(jwt);

        if (!isOnlyExpiry(result, jwt)) {
            return result;
        }

        return OAuth2TokenValidatorResult.failure(new OAuth2Error(
                TOKEN_EXPIRED_ERROR_CODE,
                "Jwt expired at %s".formatted(jwt.getExpiresAt()),
                null));
    }

    private boolean isOnlyExpiry(OAuth2TokenValidatorResult result, Jwt jwt) {
        return result.hasErrors() && result.getErrors().size() == 1 && isExpired(jwt);
    }

    /** {@code JwtTimestampValidator} 가 만료로 판정하는 조건과 같은 식이다. */
    private boolean isExpired(Jwt jwt) {
        Instant expiresAt = jwt.getExpiresAt();
        return expiresAt != null && Instant.now(clock).minus(CLOCK_SKEW).isAfter(expiresAt);
    }
}
