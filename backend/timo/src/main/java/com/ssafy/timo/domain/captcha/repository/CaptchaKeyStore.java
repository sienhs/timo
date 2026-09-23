package com.ssafy.timo.domain.captcha.repository;

import com.ssafy.timo.global.config.cache.CacheConfig;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.springframework.cache.Cache;
import org.springframework.cache.CacheManager;
import org.springframework.stereotype.Repository;

/**
 * 발급한 캡차 키와 그 주인을 들고 있는 저장소.
 *
 * <p>수명은 여기서 정하지 않는다. {@link CacheConfig} 가 캐시에 걸어 둔 만료가 곧 키의 수명이고,
 * 그 값은 {@code naver.captcha.key-ttl} 에서 온다. 저장소는 넣고 꺼내기만 한다.
 *
 * <p>키에 회원 id 를 함께 담는 이유는 남의 캡차 키를 주워 쓰는 것을 막기 위해서다. 검증할 때 이
 * 값과 요청자를 맞춰 본다.
 *
 * <p>{@code @Cacheable} 을 쓰지 않고 캐시를 직접 다룬다. 그 애노테이션은 "없으면 만들어 채운다" 는
 * 읽기 캐시용이고, 여기서 필요한 것은 명시적인 저장과 폐기다.
 */
@Repository
@RequiredArgsConstructor
public class CaptchaKeyStore {

    private final CacheManager cacheManager;

    /**
     * 캡차 키를 주인과 함께 저장한다. 만료되면 그 뒤의 검증은 "없는 키" 가 된다.
     *
     * <p>덮어쓰기다. 같은 키가 두 번 발급될 일은 없지만, 있더라도 나중 것이 맞다.
     */
    public void save(String captchaKey, Long memberId) {
        cache().put(captchaKey, memberId);
    }

    /**
     * 키를 주인과 함께 꺼내고 그 자리에서 지운다. Redis 였다면 {@code GETDEL} 이었을 자리다.
     *
     * <p>결과와 무관하게 이 호출로 폐기된다 - 키는 1회용이라, 오답이든 남의 키로 시도했든 같은 키로
     * 다시 검증하면 {@code CAPTCHA_KEY_NOT_FOUND} 여야 한다. 호출부가 이 값을 보고 오답·소유자
     * 불일치를 가른다.
     *
     * @return 저장된 주인 회원 id. 키가 없거나 이미 만료·소비됐으면 빈 값
     */
    public Optional<Long> getAndEvict(String captchaKey) {
        Cache cache = cache();
        Long memberId = cache.get(captchaKey, Long.class);
        cache.evict(captchaKey);
        return Optional.ofNullable(memberId);
    }

    private Cache cache() {
        Cache cache = cacheManager.getCache(CacheConfig.CAPTCHA_KEYS);
        if (cache == null) {
            // 캐시 이름이 어긋나면 조용히 통과해서는 안 된다 - 캡차가 통째로 무력해진다.
            throw new IllegalStateException("캐시가 없습니다: " + CacheConfig.CAPTCHA_KEYS);
        }
        return cache;
    }
}
