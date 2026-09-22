package com.ssafy.timo.domain.waitingqueue.service;

import com.ssafy.timo.domain.waitingqueue.dto.WaitingQueueResponseDto;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.stereotype.Service;

/** Redis는 입장량만 제어한다. 실제 좌석 선점과 주문 정합성은 기존 MySQL 트랜잭션이 계속 책임진다. */
@Service
@RequiredArgsConstructor
public class WaitingQueueServiceImpl implements WaitingQueueService {
    private static final String JOIN_OR_STATUS_SCRIPT = """
            redis.call('ZREMRANGEBYSCORE', KEYS[1], '-inf', ARGV[2])
            local expiresAt = redis.call('ZSCORE', KEYS[1], ARGV[1])
            if expiresAt then
                local existingToken = redis.call('GET', KEYS[4])
                if existingToken then
                    return 'ADMITTED|0|' .. existingToken .. '|' .. expiresAt
                end
                redis.call('ZREM', KEYS[1], ARGV[1])
            end
            if ARGV[6] == 'join' and not redis.call('ZSCORE', KEYS[2], ARGV[1]) then
                local sequence = redis.call('INCR', KEYS[3])
                redis.call('ZADD', KEYS[2], sequence, ARGV[1])
            end
            local rank = redis.call('ZRANK', KEYS[2], ARGV[1])
            local active = redis.call('ZCARD', KEYS[1])
            if rank == 0 and active < tonumber(ARGV[3]) then
                local admissionExpiresAt = tonumber(ARGV[2]) + tonumber(ARGV[4])
                redis.call('ZREM', KEYS[2], ARGV[1])
                redis.call('ZADD', KEYS[1], admissionExpiresAt, ARGV[1])
                redis.call('SET', KEYS[4], ARGV[5], 'PX', ARGV[4])
                return 'ADMITTED|0|' .. ARGV[5] .. '|' .. admissionExpiresAt
            end
            if rank then
                return 'WAITING|' .. rank .. '||'
            end
            return 'WAITING|||'
            """;
    private static final String LEAVE_SCRIPT = """
            redis.call('ZREM', KEYS[1], ARGV[1])
            redis.call('ZREM', KEYS[2], ARGV[1])
            redis.call('DEL', KEYS[3])
            return 1
            """;
    private static final DefaultRedisScript<String> JOIN_OR_STATUS = new DefaultRedisScript<>(JOIN_OR_STATUS_SCRIPT, String.class);
    private static final DefaultRedisScript<Long> LEAVE = new DefaultRedisScript<>(LEAVE_SCRIPT, Long.class);

    private final StringRedisTemplate redis;
    private final SecureRandom random = new SecureRandom();

    @Value("${waiting-queue.active-limit:100}")
    private long activeLimit;
    @Value("${waiting-queue.admission-ttl:PT5M}")
    private Duration admissionTtl;

    @Override
    public WaitingQueueResponseDto join(Long concertId, Long memberId) {
        return executeJoinOrStatus(concertId, memberId, "join");
    }

    @Override
    public WaitingQueueResponseDto status(Long concertId, Long memberId) {
        return executeJoinOrStatus(concertId, memberId, "status");
    }

    @Override
    public void leave(Long concertId, Long memberId) {
        redis.execute(LEAVE, List.of(activeKey(concertId), waitingKey(concertId), tokenKey(concertId, memberId)), member(memberId));
    }

    private WaitingQueueResponseDto executeJoinOrStatus(Long concertId, Long memberId, String command) {
        long now = System.currentTimeMillis();
        String result = redis.execute(
                JOIN_OR_STATUS,
                List.of(activeKey(concertId), waitingKey(concertId), sequenceKey(concertId), tokenKey(concertId, memberId)),
                member(memberId), Long.toString(now), Long.toString(activeLimit), Long.toString(admissionTtl.toMillis()), token(), command);
        if (result == null) throw new IllegalStateException("대기열 Redis 스크립트 결과가 없습니다.");
        String[] values = result.split("\\|", -1);
        if (values.length != 4) throw new IllegalStateException("대기열 Redis 스크립트 결과 형식이 올바르지 않습니다.");
        if ("ADMITTED".equals(values[0])) {
            return new WaitingQueueResponseDto("ADMITTED", 0L, values[2], Instant.ofEpochMilli(Long.parseLong(values[3])));
        }
        return new WaitingQueueResponseDto("WAITING", values[1].isBlank() ? null : Long.parseLong(values[1]), null, null);
    }

    private String token() { byte[] value = new byte[24]; random.nextBytes(value); return Base64.getUrlEncoder().withoutPadding().encodeToString(value); }
    private String waitingKey(Long id) { return "waiting-queue:" + id + ":waiting"; }
    private String activeKey(Long id) { return "waiting-queue:" + id + ":active"; }
    private String sequenceKey(Long id) { return "waiting-queue:" + id + ":sequence"; }
    private String tokenKey(Long concertId, Long memberId) { return "waiting-queue:" + concertId + ":token:" + memberId; }
    private String member(Long memberId) { return memberId.toString(); }
}
