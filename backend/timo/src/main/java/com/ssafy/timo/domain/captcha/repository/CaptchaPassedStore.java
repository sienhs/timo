package com.ssafy.timo.domain.captcha.repository;

import com.ssafy.timo.global.config.cache.CacheConfig;
import lombok.RequiredArgsConstructor;
import org.springframework.cache.Cache;
import org.springframework.cache.CacheManager;
import org.springframework.stereotype.Repository;

/**
 * 캡차를 통과한 (공연, 회원) 조합을 들고 있는 저장소.
 *
 * <p>원안의 Redis 키 {@code captcha:passed:{concertId}:{userId}} 를 캐시 항목 하나로 읽는다 -
 * {@link CaptchaKeyStore} 와 같은 사정이다({@code CacheConfig} 참고). 수명은
 * {@code naver.captcha.passed-ttl} 이고 만료는 {@link CacheConfig} 가 캐시에 걸어 둔다.
 *
 * <p>발급 키와 달리 여기는 쓰고 버리지 않는다. 좌석 조회마다 통과 여부를 다시 묻게 될 것이라(B8),
 * 한 번 읽었다고 지우면 같은 공연을 다시 조회할 때마다 캡차를 또 풀어야 한다.
 */
@Repository
@RequiredArgsConstructor
public class CaptchaPassedStore {

    private final CacheManager cacheManager;

    /** 이 회원이 이 공연의 캡차를 통과했다고 남긴다. */
    public void markPassed(Long concertId, Long memberId) {
        cache().put(key(concertId, memberId), Boolean.TRUE);
    }

    /**
     * 통과 기록이 있는지 본다. <b>조회만 하고 지우지 않는다.</b> 좌석 조회처럼 반복 호출되는 API 가
     * 호출할 때마다 다시 캡차를 풀게 하면 안 된다({@code RequireCaptchaInterceptor}).
     */
    public boolean hasPassed(Long concertId, Long memberId) {
        Boolean passed = cache().get(key(concertId, memberId), Boolean.class);
        return Boolean.TRUE.equals(passed);
    }

    private Cache cache() {
        Cache cache = cacheManager.getCache(CacheConfig.CAPTCHA_PASSED);
        if (cache == null) {
            // 캐시 이름이 어긋나면 조용히 통과해서는 안 된다 - 통과 기록이 통째로 사라진다.
            throw new IllegalStateException("캐시가 없습니다: " + CacheConfig.CAPTCHA_PASSED);
        }
        return cache;
    }

    private String key(Long concertId, Long memberId) {
        return concertId + ":" + memberId;
    }
}
