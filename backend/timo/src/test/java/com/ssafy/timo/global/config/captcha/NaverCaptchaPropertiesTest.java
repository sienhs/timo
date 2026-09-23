package com.ssafy.timo.global.config.captcha;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Duration;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.boot.context.properties.bind.Binder;
import org.springframework.boot.context.properties.source.MapConfigurationPropertySource;
import org.springframework.boot.test.context.ConfigDataApplicationContextInitializer;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

/**
 * 설정이 잘못되면 첫 캡차 요청이 아니라 기동 시점에 걸려야 한다.
 *
 * <p>뒤쪽 두 테스트는 실제 {@code application.yml} 을 읽는다. {@code passed-ttl} 이 대기열 값을
 * 따라가는 것은 레코드가 아니라 yml 의 플레이스홀더가 하는 일이라, 바인딩만 봐서는 검증되지 않는다.
 */
class NaverCaptchaPropertiesTest {

    private static final Map<String, Object> REQUIRED = Map.of(
            "naver.captcha.client-id", "test-id",
            "naver.captcha.client-secret", "test-secret");

    private final ApplicationContextRunner runner = new ApplicationContextRunner()
            .withInitializer(new ConfigDataApplicationContextInitializer())
            .withUserConfiguration(CaptchaConfig.class);

    @Test
    @DisplayName("자격증명만 주면 나머지는 기본값으로 채워진다")
    void bindsDefaults() {
        NaverCaptchaProperties properties = bind(REQUIRED);

        assertThat(properties.baseUrl()).isEqualTo("https://openapi.naver.com");
        assertThat(properties.keyTtl()).isEqualTo(Duration.ofMinutes(2));
        assertThat(properties.passedTtl()).isEqualTo(Duration.ofMinutes(5));
        assertThat(properties.issueLimitPerMinute()).isEqualTo(10);
        assertThat(properties.maxConcurrentCalls()).isEqualTo(50);
    }

    @Test
    @DisplayName("client-secret 이 비어 있으면 기동 실패 - 네이버가 주는 401 이 502 로 둔갑하는 것을 막는다")
    void rejectsBlankSecret() {
        assertThatThrownBy(() -> new NaverCaptchaProperties("id", " ", "https://openapi.naver.com",
                Duration.ofMinutes(2), Duration.ofMinutes(5), 10, 50))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("client-secret");
    }

    @Test
    @DisplayName("발급 한도가 1 미만이면 기동 실패 - 아무도 캡차를 받을 수 없는 설정이다")
    void rejectsNonPositiveIssueLimit() {
        assertThatThrownBy(() -> new NaverCaptchaProperties("id", "secret", "https://openapi.naver.com",
                Duration.ofMinutes(2), Duration.ofMinutes(5), 0, 50))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("issue-limit-per-minute");
    }

    @Test
    @DisplayName("동시 호출 상한이 1 미만이면 기동 실패 - 모두를 거절하는 설정이다")
    void rejectsNonPositiveMaxConcurrentCalls() {
        assertThatThrownBy(() -> new NaverCaptchaProperties("id", "secret", "https://openapi.naver.com",
                Duration.ofMinutes(2), Duration.ofMinutes(5), 10, 0))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("max-concurrent-calls");
    }

    @Test
    @DisplayName("toString 에 client-secret 이 드러나지 않는다")
    void masksSecretInToString() {
        String text = bind(REQUIRED).toString();

        assertThat(text).doesNotContain("test-secret");
        assertThat(text).contains("test-id");
    }

    @Test
    @DisplayName("passed-ttl 은 대기열 입장 유효 시간을 따라간다")
    void passedTtlFollowsAdmissionTtl() {
        runner.withPropertyValues("waiting-queue.admission-ttl=PT9M")
                .run(context -> assertThat(context.getBean(NaverCaptchaProperties.class).passedTtl())
                        .isEqualTo(Duration.ofMinutes(9)));
    }

    @Test
    @DisplayName("대기열 값이 없는 프로파일에서는 5분으로 떨어진다 - 환경변수 없이도 뜬다")
    void passedTtlFallsBackWithoutAdmissionTtl() {
        runner.run(context -> assertThat(context.getBean(NaverCaptchaProperties.class).passedTtl())
                .isEqualTo(Duration.ofMinutes(5)));
    }

    private NaverCaptchaProperties bind(Map<String, Object> properties) {
        return new Binder(new MapConfigurationPropertySource(properties))
                .bind("naver.captcha", NaverCaptchaProperties.class)
                .get();
    }
}
