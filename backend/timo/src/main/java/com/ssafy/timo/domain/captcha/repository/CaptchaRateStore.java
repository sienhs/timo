package com.ssafy.timo.domain.captcha.repository;

import com.ssafy.timo.global.config.cache.CacheConfig;
import java.util.concurrent.atomic.AtomicInteger;
import lombok.RequiredArgsConstructor;
import org.springframework.cache.Cache;
import org.springframework.cache.CacheManager;
import org.springframework.stereotype.Repository;

/**
 * 회원별 캡차 발급 횟수를 세는 저장소.
 *
 * <p>창의 길이는 여기서 정하지 않는다. {@link CacheConfig} 가 캐시에 걸어 둔 만료가 곧 창이다.
 *
 * <p><b>세는 값이 {@link AtomicInteger} 인 이유.</b> 캐시에 정수를 넣고 꺼내 더해 다시 넣으면
 * 두 요청이 같은 값을 읽어 하나가 덮어쓰는 구간이 생겨, 한도를 넘겨도 통과한다. 항목을 만드는
 * 것만 캐시에 맡기고(그 생성은 원자적이다) 증가는 그 안의 카운터에 맡긴다.
 */
@Repository
@RequiredArgsConstructor
public class CaptchaRateStore {

    private final CacheManager cacheManager;

    /**
     * 이번 창에서 이 회원의 발급 시도를 하나 세고, 센 뒤의 값을 돌려준다.
     *
     * <p>첫 시도면 1 이다. 창이 지나 항목이 사라졌으면 다시 1 부터 센다.
     */
    public int increment(Long memberId) {
        return counter(memberId).incrementAndGet();
    }

    private AtomicInteger counter(Long memberId) {
        Cache cache = cacheManager.getCache(CacheConfig.CAPTCHA_RATES);
        if (cache == null) {
            // 캐시 이름이 어긋나면 조용히 통과해서는 안 된다 - 제한이 통째로 사라진다.
            throw new IllegalStateException("캐시가 없습니다: " + CacheConfig.CAPTCHA_RATES);
        }
        return cache.get(memberId, AtomicInteger::new);
    }
}
