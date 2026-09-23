package com.ssafy.timo.domain.captcha.repository;

import static org.assertj.core.api.Assertions.assertThat;

import com.ssafy.timo.global.config.cache.CacheConfig;
import com.ssafy.timo.global.config.captcha.NaverCaptchaProperties;
import java.time.Duration;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.cache.CacheManager;

/** 실제 캐시를 그대로 쓴다 - 세는 방식이 캐시 동작에 기대고 있어 가짜로 바꾸면 검증이 사라진다. */
class CaptchaRateStoreTest {

    private static final Long MEMBER_ID = 7L;

    private CaptchaRateStore captchaRateStore;

    @BeforeEach
    void setUp() {
        CacheManager cacheManager = new CacheConfig().cacheManager(new NaverCaptchaProperties(
                "id", "secret", "https://openapi.naver.com",
                Duration.ofMinutes(2), Duration.ofMinutes(5), 10, 50));
        captchaRateStore = new CaptchaRateStore(cacheManager);
    }

    @Test
    @DisplayName("첫 시도는 1 이고 부를 때마다 하나씩 오른다")
    void countsFromOne() {
        assertThat(captchaRateStore.increment(MEMBER_ID)).isEqualTo(1);
        assertThat(captchaRateStore.increment(MEMBER_ID)).isEqualTo(2);
        assertThat(captchaRateStore.increment(MEMBER_ID)).isEqualTo(3);
    }

    @Test
    @DisplayName("회원마다 따로 센다 - 남의 발급이 내 한도를 깎으면 안 된다")
    void countsPerMember() {
        captchaRateStore.increment(MEMBER_ID);
        captchaRateStore.increment(MEMBER_ID);

        assertThat(captchaRateStore.increment(8L)).isEqualTo(1);
    }
}
