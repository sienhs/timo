package com.ssafy.timo.global.config.cache;

import static org.assertj.core.api.Assertions.assertThat;

import com.ssafy.timo.global.config.captcha.NaverCaptchaProperties;
import java.time.Duration;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.cache.CacheManager;
import org.springframework.cache.caffeine.CaffeineCache;

/**
 * 캡차 키의 수명은 이 설정이 정한다. 저장소 코드에는 만료가 없어, 여기서 어긋나면 키가 영원히
 * 살아남아도 아무 테스트도 깨지지 않는다.
 */
class CacheConfigTest {

    @Test
    @DisplayName("캡차 키 캐시는 key-ttl 만큼만 산다")
    void captchaKeyCacheExpiresAfterKeyTtl() {
        Duration keyTtl = Duration.ofMinutes(2);
        CacheManager cacheManager = new CacheConfig().cacheManager(properties(keyTtl));

        CaffeineCache cache = (CaffeineCache) cacheManager.getCache(CacheConfig.CAPTCHA_KEYS);

        assertThat(cache).isNotNull();
        assertThat(cache.getNativeCache().policy().expireAfterWrite())
                .hasValueSatisfying(policy -> assertThat(policy.getExpiresAfter()).isEqualTo(keyTtl));
    }

    @Test
    @DisplayName("설정의 key-ttl 을 바꾸면 캐시 수명도 따라간다")
    void followsConfiguredKeyTtl() {
        Duration keyTtl = Duration.ofSeconds(30);
        CacheManager cacheManager = new CacheConfig().cacheManager(properties(keyTtl));

        CaffeineCache cache = (CaffeineCache) cacheManager.getCache(CacheConfig.CAPTCHA_KEYS);

        assertThat(cache.getNativeCache().policy().expireAfterWrite())
                .hasValueSatisfying(policy -> assertThat(policy.getExpiresAfter()).isEqualTo(keyTtl));
    }

    @Test
    @DisplayName("발급 횟수 캐시의 창은 1분이다 - 설정 이름이 '분당' 이라 창도 분이어야 한다")
    void rateCacheWindowIsOneMinute() {
        CacheManager cacheManager = new CacheConfig().cacheManager(properties(Duration.ofMinutes(2)));

        CaffeineCache cache = (CaffeineCache) cacheManager.getCache(CacheConfig.CAPTCHA_RATES);

        assertThat(cache).isNotNull();
        assertThat(cache.getNativeCache().policy().expireAfterWrite())
                .hasValueSatisfying(policy ->
                        assertThat(policy.getExpiresAfter()).isEqualTo(Duration.ofMinutes(1)));
    }

    private NaverCaptchaProperties properties(Duration keyTtl) {
        return new NaverCaptchaProperties("id", "secret", "https://openapi.naver.com",
                keyTtl, Duration.ofMinutes(5), 10, 50);
    }
}
