package com.ssafy.timo.global.config.auth;

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * JWT 설정. 프로파일마다 다른 비밀키는 {@code application-{profile}.yml} 에,
 * 어디서나 같은 수명은 {@code application.yml} 에 둔다.
 *
 * @param secret         HS256 대칭키. 프로파일별로 다르다
 * @param accessTokenTtl access token 수명. 비워 두면 30분
 */
@ConfigurationProperties(prefix = "jwt")
public record JwtProperties(String secret, Duration accessTokenTtl) {

    /** HS256 은 키가 256비트 이상이어야 한다. 짧으면 Nimbus 가 발급 시점에 거부한다. */
    private static final int MIN_SECRET_BYTES = 32;

    private static final Duration DEFAULT_ACCESS_TOKEN_TTL = Duration.ofMinutes(30);

    public JwtProperties {
        if (secret == null || secret.getBytes(StandardCharsets.UTF_8).length < MIN_SECRET_BYTES) {
            // 기동 시점에 터뜨린다. 첫 로그인 요청에서 알게 되면 이미 배포된 뒤다.
            throw new IllegalStateException(
                    "jwt.secret 은 최소 %d바이트여야 합니다. (현재: %d바이트)".formatted(
                            MIN_SECRET_BYTES,
                            secret == null ? 0 : secret.getBytes(StandardCharsets.UTF_8).length));
        }
        if (accessTokenTtl == null) {
            accessTokenTtl = DEFAULT_ACCESS_TOKEN_TTL;
        }
    }

    /** 기본 toString 은 비밀키를 그대로 노출한다. 바인딩 실패 로그나 configprops 에 새지 않게 가린다. */
    @Override
    public String toString() {
        return "JwtProperties[secret=<%d bytes>, accessTokenTtl=%s]"
                .formatted(secret.getBytes(StandardCharsets.UTF_8).length, accessTokenTtl);
    }
}
