package com.ssafy.timo.global.config.captcha;

import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * 네이버 캡차(openapi.naver.com) 연동 설정.
 *
 * <p>자격증명은 프로파일마다 다르다({@code application-{profile}.yml}). 나머지는 환경이 갈릴 이유가
 * 없어 {@code application.yml} 한 곳에 둔다 - {@code jwt.secret} 과 {@code jwt.access-token-ttl} 을
 * 나눠 둔 것과 같은 기준이다.
 *
 * <p><b>{@code passedTtl} 은 대기열 입장 유효 시간을 따라간다.</b> 통과 기록이 입장 자격보다 오래
 * 살아 있으면, 대기열에서 밀려난 사용자가 캡차 없이 좌석 조회를 이어갈 수 있는 창이 생긴다. 반대로
 * 더 짧으면 한 번의 입장 안에서 캡차를 두 번 풀게 된다. 그래서 값을 여기 적어 두지 않고
 * {@code application.yml} 에서 {@code ${waiting-queue.admission-ttl:PT5M}} 로 받아, 대기열 쪽 값을
 * 바꾸면 이쪽이 자동으로 따라오게 했다. 아래 기본값은 그 속성이 정의되지 않은 프로파일(local·test)
 * 에서 쓰이는 것으로, {@code WaitingQueueServiceImpl} 이 갖는 기본값과 같은 {@code PT5M} 이다.
 *
 * @param clientId            네이버 오픈 API 애플리케이션 ID. 요청 헤더로 나간다
 * @param clientSecret        같은 애플리케이션의 비밀키. 로그·응답 어디에도 남기지 않는다
 * @param baseUrl             캡차 API 호스트
 * @param keyTtl              발급한 캡차 키의 수명. 이 안에 풀지 못하면 키가 사라진다
 * @param passedTtl           캡차 통과 기록의 수명. 대기열 입장 유효 시간과 같아야 한다
 * @param issueLimitPerMinute 사용자 한 명이 1분 동안 받을 수 있는 캡차 수
 * @param maxConcurrentCalls  네이버로 동시에 나갈 수 있는 호출 수 상한. {@link NaverCaptchaClient} 가
 *                            이 수를 넘는 순간 대기 없이 502 로 거절한다 - 숫자 자체는
 *                            {@code docs/BE_CAPTCHA_TASK_BREAKDOWN.md} 의 "B9 전에 볼 것" 항목대로
 *                            부하테스트로 실측 전 추정치다
 */
@ConfigurationProperties(prefix = "naver.captcha")
public record NaverCaptchaProperties(String clientId,
                                     String clientSecret,
                                     @DefaultValue("https://openapi.naver.com") String baseUrl,
                                     @DefaultValue("PT2M") Duration keyTtl,
                                     @DefaultValue("PT5M") Duration passedTtl,
                                     @DefaultValue("10") int issueLimitPerMinute,
                                     @DefaultValue("50") int maxConcurrentCalls) {

    public NaverCaptchaProperties {
        requireText("client-id", clientId);
        requireText("client-secret", clientSecret);
        requireText("base-url", baseUrl);
        requirePositive("key-ttl", keyTtl);
        requirePositive("passed-ttl", passedTtl);
        if (issueLimitPerMinute < 1) {
            throw new IllegalStateException(
                    "naver.captcha.issue-limit-per-minute 는 1 이상이어야 합니다: " + issueLimitPerMinute);
        }
        if (maxConcurrentCalls < 1) {
            throw new IllegalStateException(
                    "naver.captcha.max-concurrent-calls 는 1 이상이어야 합니다: " + maxConcurrentCalls);
        }
    }

    /**
     * 값이 없으면 기동 시점에 터뜨린다. 비어 있는 채로 뜨면 네이버가 401 을 주는데, 그것이
     * {@code CAPTCHA_PROVIDER_ERROR}(502) 로 변환돼 나가므로 설정 누락이 장애처럼 보인다.
     */
    private static void requireText(String name, String value) {
        if (value == null || value.isBlank()) {
            throw new IllegalStateException("naver.captcha.%s 가 비어 있습니다.".formatted(name));
        }
    }

    private static void requirePositive(String name, Duration value) {
        if (value == null || value.isZero() || value.isNegative()) {
            throw new IllegalStateException(
                    "naver.captcha.%s 는 0보다 커야 합니다: %s".formatted(name, value));
        }
    }

    /**
     * 기본 {@code toString} 은 비밀키를 그대로 노출한다. 바인딩 실패 로그나 {@code /actuator/configprops}
     * 에 새지 않게 가린다 - {@code EntryPassProperties} 와 같은 이유다. ID 는 어차피 요청 헤더로 나가는
     * 값이라 가리지 않는다.
     */
    @Override
    public String toString() {
        return ("NaverCaptchaProperties[clientId=%s, clientSecret=<%d chars>, baseUrl=%s, keyTtl=%s, "
                + "passedTtl=%s, issueLimitPerMinute=%d, maxConcurrentCalls=%d]")
                .formatted(clientId, clientSecret.length(), baseUrl, keyTtl, passedTtl, issueLimitPerMinute,
                        maxConcurrentCalls);
    }
}
