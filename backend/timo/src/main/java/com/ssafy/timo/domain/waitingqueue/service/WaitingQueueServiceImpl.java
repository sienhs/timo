package com.ssafy.timo.domain.waitingqueue.service;

import com.ssafy.timo.domain.waitingqueue.dto.WaitingQueueResponseDto;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

/** Redis는 입장량만 제어한다. 실제 좌석 선점과 주문 정합성은 기존 MySQL 트랜잭션이 계속 책임진다. */
@Service
@RequiredArgsConstructor
public class WaitingQueueServiceImpl implements WaitingQueueService {
    private final StringRedisTemplate redis;
    private final SecureRandom random = new SecureRandom();

    @Value("${waiting-queue.active-limit:100}")
    private long activeLimit;
    @Value("${waiting-queue.admission-ttl:PT5M}")
    private Duration admissionTtl;

    @Override
    public synchronized WaitingQueueResponseDto join(Long concertId, Long memberId) {
        promote(concertId);
        if (redis.opsForZSet().score(activeKey(concertId), member(memberId)) == null
                && redis.opsForZSet().score(waitingKey(concertId), member(memberId)) == null) {
            Long sequence = redis.opsForValue().increment(sequenceKey(concertId));
            redis.opsForZSet().add(waitingKey(concertId), member(memberId), sequence == null ? 0 : sequence);
        }
        promote(concertId);
        return status(concertId, memberId);
    }

    @Override
    public synchronized WaitingQueueResponseDto status(Long concertId, Long memberId) {
        promote(concertId);
        String member = member(memberId);
        Double expires = redis.opsForZSet().score(activeKey(concertId), member);
        if (expires != null) {
            String token = redis.opsForValue().get(tokenKey(concertId, memberId));
            if (token != null) return new WaitingQueueResponseDto("ADMITTED", 0L, token, Instant.ofEpochMilli(expires.longValue()));
        }
        Long rank = redis.opsForZSet().rank(waitingKey(concertId), member);
        return new WaitingQueueResponseDto("WAITING", rank == null ? null : rank, null, null);
    }

    @Override
    public synchronized void leave(Long concertId, Long memberId) {
        String member = member(memberId);
        redis.opsForZSet().remove(waitingKey(concertId), member);
        redis.opsForZSet().remove(activeKey(concertId), member);
        redis.delete(tokenKey(concertId, memberId));
        promote(concertId);
    }

    private void promote(Long concertId) {
        long now = System.currentTimeMillis();
        redis.opsForZSet().removeRangeByScore(activeKey(concertId), 0, now);
        Long active = redis.opsForZSet().zCard(activeKey(concertId));
        long slots = Math.max(0, activeLimit - (active == null ? 0 : active));
        if (slots == 0) return;
        Set<String> next = redis.opsForZSet().range(waitingKey(concertId), 0, slots - 1);
        if (next == null) return;
        long expires = now + admissionTtl.toMillis();
        for (String member : next) {
            redis.opsForZSet().remove(waitingKey(concertId), member);
            redis.opsForZSet().add(activeKey(concertId), member, expires);
            redis.opsForValue().set(tokenKey(concertId, Long.valueOf(member)), token(), admissionTtl);
        }
    }

    private String token() { byte[] value = new byte[24]; random.nextBytes(value); return Base64.getUrlEncoder().withoutPadding().encodeToString(value); }
    private String waitingKey(Long id) { return "waiting-queue:" + id + ":waiting"; }
    private String activeKey(Long id) { return "waiting-queue:" + id + ":active"; }
    private String sequenceKey(Long id) { return "waiting-queue:" + id + ":sequence"; }
    private String tokenKey(Long concertId, Long memberId) { return "waiting-queue:" + concertId + ":token:" + memberId; }
    private String member(Long memberId) { return memberId.toString(); }
}
