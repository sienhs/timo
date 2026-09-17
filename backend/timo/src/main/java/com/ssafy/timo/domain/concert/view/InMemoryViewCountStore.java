package com.ssafy.timo.domain.concert.view;

import org.springframework.stereotype.Component;

import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * 단일 애플리케이션 인스턴스용 조회수 저장소.
 *
 * <p>공연별 원자 카운터를 사용하므로 같은 공연 상세 조회가 동시에 들어와도 증가분을 잃지 않는다.
 * 애플리케이션 재시작 또는 다중 인스턴스 환경에서는 증가분이 공유되지 않으므로, 그 시점에는
 * {@link ViewCountStore}의 Redis 구현체로 교체한다.
 */
@Component
public class InMemoryViewCountStore implements ViewCountStore {

    private final ConcurrentMap<Long, AtomicInteger> viewCounts = new ConcurrentHashMap<>();

    @Override
    public int incrementAndGet(long concertId, int persistedViewCount) {
        return viewCounts.computeIfAbsent(concertId, ignored -> new AtomicInteger(persistedViewCount))
                .incrementAndGet();
    }
}
