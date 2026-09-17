package com.ssafy.timo.global.config;

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 입장 QR({@code timo:entry:...}) 서명 설정.
 *
 * <p>비밀키를 {@link JwtProperties#secret()} 과 공유하지 않는다. 용도가 다른 두 토큰이 같은 키를
 * 쓰면 한쪽이 털렸을 때 둘 다 위조된다. 무엇보다 입장 QR 은 공연장에서 수천 번 촬영되고 화면에
 * 그대로 노출되는 값이라, 로그인 세션과 같은 키로 서명할 이유가 없다.
 *
 * @param secret HMAC-SHA256 대칭키. 프로파일마다 다르다
 * @param ttl    QR 한 장의 수명. 비워 두면 30초
 */
@ConfigurationProperties(prefix = "entry-pass")
public record EntryPassProperties(String secret, Duration ttl) {

    /** HMAC-SHA256 의 블록 크기. 키가 이보다 짧으면 해시 강도를 그만큼 깎아 먹는다. */
    private static final int MIN_SECRET_BYTES = 32;

    /**
     * 팬 앱이 처음부터 30초 주기로 QR 을 돌려 왔고({@code EntryPass.lifetime}), 화면의
     * 카운트다운도 그 주기에 맞춰 그려진다. 서버가 다른 수명을 쓰면 남은 시간 표시와 실제 만료가
     * 어긋나므로 같은 값으로 맞춘다.
     *
     * <p>더 짧게 가져갈 이유는 없다. 캡처 전달을 막는 진짜 방어선은 수명이 아니라 입장 처리 뒤
     * 티켓이 {@code USED} 로 바뀌는 것이고, 수명을 줄일수록 셀룰러가 최악인 공연장 입구에서
     * "화면에 띄웠는데 이미 만료된 QR" 만 늘어난다.
     */
    private static final Duration DEFAULT_TTL = Duration.ofSeconds(30);

    public EntryPassProperties {
        if (secret == null || secret.getBytes(StandardCharsets.UTF_8).length < MIN_SECRET_BYTES) {
            // 기동 시점에 터뜨린다. 공연 당일 첫 스캔에서 알게 되면 이미 줄이 서 있다.
            throw new IllegalStateException(
                    "entry-pass.secret 은 최소 %d바이트여야 합니다. (현재: %d바이트)".formatted(
                            MIN_SECRET_BYTES,
                            secret == null ? 0 : secret.getBytes(StandardCharsets.UTF_8).length));
        }
        if (ttl == null) {
            ttl = DEFAULT_TTL;
        }
    }

    /** 기본 toString 은 비밀키를 그대로 노출한다. 바인딩 실패 로그나 configprops 에 새지 않게 가린다. */
    @Override
    public String toString() {
        return "EntryPassProperties[secret=<%d bytes>, ttl=%s]"
                .formatted(secret.getBytes(StandardCharsets.UTF_8).length, ttl);
    }
}
