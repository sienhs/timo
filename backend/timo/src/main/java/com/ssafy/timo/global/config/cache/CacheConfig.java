package com.ssafy.timo.global.config.cache;

import com.github.benmanes.caffeine.cache.Caffeine;
import com.ssafy.timo.global.config.captcha.NaverCaptchaProperties;
import java.time.Duration;
import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.cache.caffeine.CaffeineCacheManager;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * 캐시 설정.
 *
 * <p><b>이 캐시들은 성능이 아니라 상태를 담는다.</b> 캡차가 쓰는 값은 전부 "일정 시간 뒤에 사라져야
 * 한다" 가 곧 정책인 것들이라, 만료를 캐시에 맡기고 도메인 코드는 넣고 꺼내기만 한다.
 *
 * <p>구현으로 Caffeine 을 쓰는 이유는 만료 때문이다. 스프링 기본
 * {@code ConcurrentMapCacheManager} 에는 TTL 이 없어, 한 번 들어간 캡차 키가 영원히 남아 재사용
 * 가능해지고 메모리도 무한히 늘어난다.
 *
 * <p><b>프로세스 메모리다.</b> 서버가 여러 대로 늘면 캡차를 발급한 인스턴스와 검증하는 인스턴스가
 * 달라져 방금 받은 캡차가 없는 키로 보인다. 지금 운영이 EC2 한 대이고, SMS 인증 상태도 같은 전제로
 * {@code SmsVerificationStore} 가 메모리에 들고 있다. 인스턴스를 늘릴 때는 두 곳을 함께 Redis 로
 * 옮겨야 한다.
 */
@Configuration
@EnableCaching
public class CacheConfig {

    /** 발급한 캡차 키 → 그 주인의 회원 id. */
    public static final String CAPTCHA_KEYS = "captchaKeys";

    /** 회원 id → 이번 창에서 발급받은 횟수. */
    public static final String CAPTCHA_RATES = "captchaRates";

    /** "{공연 id}:{회원 id}" → 캡차 통과 여부. 원안의 {@code captcha:passed:{concertId}:{userId}} 를 읽는다. */
    public static final String CAPTCHA_PASSED = "captchaPassed";

    /**
     * 발급 횟수를 세는 창의 길이. {@code naver.captcha.issue-limit-per-minute} 가 "분당" 몇 건인지를
     * 정하므로 창도 1분으로 고정이다 - 둘이 갈리면 설정 이름이 거짓말이 된다.
     *
     * <p>고정 창이다. 첫 발급에서 항목이 생기고 1분 뒤 통째로 사라진다. 창 경계에서는 짧은 구간에
     * 한도의 두 배까지 나갈 수 있는데, 여기서 막으려는 것이 정밀한 유량 제어가 아니라 네이버 API
     * 호출 한도를 축내는 폭주라 그 정도 오차는 받아들인다.
     */
    private static final Duration RATE_WINDOW = Duration.ofMinutes(1);

    /**
     * 캐시 하나에 담아 둘 최대 항목 수. 캡차 키는 수명이 2분이고 발급도 회원당 분당 몇 건으로
     * 묶여 있어 정상 상황에서는 훨씬 아래에 머문다. 발급을 퍼붓는 요청이 들어와도 메모리가 끝까지
     * 늘지 않게 하는 상한이다.
     */
    private static final long MAX_ENTRIES = 10_000;

    @Bean
    public CacheManager cacheManager(NaverCaptchaProperties captchaProperties) {
        CaffeineCacheManager cacheManager = new CaffeineCacheManager();
        cacheManager.setAllowNullValues(false);

        // 만료 기준은 쓴 시점이다. 캡차 키의 수명은 "발급한 지 얼마나 지났는가" 이지 "마지막으로
        // 조회한 지" 가 아니므로 expireAfterAccess 를 쓰면 안 된다.
        cacheManager.registerCustomCache(CAPTCHA_KEYS, Caffeine.newBuilder()
                .expireAfterWrite(captchaProperties.keyTtl())
                .maximumSize(MAX_ENTRIES)
                .build());

        // 창이 1분이라 만료도 그에 맞춘다. 카운터 값을 올리는 것은 캐시에 대한 쓰기가 아니므로
        // (담긴 AtomicInteger 를 그 자리에서 고친다) 창이 요청마다 뒤로 밀리지 않는다 - 밀리면
        // 계속 두드리는 동안 영영 만료되지 않는 슬라이딩 창이 된다.
        cacheManager.registerCustomCache(CAPTCHA_RATES, Caffeine.newBuilder()
                .expireAfterWrite(RATE_WINDOW)
                .maximumSize(MAX_ENTRIES)
                .build());

        // 통과 기록의 수명은 발급 키와 달리 설정값(대기열 입장 유효 시간을 따라감)이다.
        // naver.captcha.passed-ttl 참고.
        cacheManager.registerCustomCache(CAPTCHA_PASSED, Caffeine.newBuilder()
                .expireAfterWrite(captchaProperties.passedTtl())
                .maximumSize(MAX_ENTRIES)
                .build());

        return cacheManager;
    }
}
