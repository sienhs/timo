package com.ssafy.timo.domain.auth.repository;

import java.time.Duration;
import java.util.Map;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.springframework.data.redis.core.HashOperations;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Repository;

@Repository
@RequiredArgsConstructor
public class SmsVerificationStore {

    private static final String CODE_KEY = "sms:code:%s";
    private static final String COOLDOWN_KEY = "sms:limit:cooldown:%s";
    private static final String DAILY_KEY = "sms:limit:daily:%s";
    private static final String IP_KEY = "sms:limit:ip:%s";
    private static final String TICKET_KEY = "sms:ticket:%s";

    private static final String FIELD_CODE_HASH = "codeHash";
    private static final String FIELD_ATTEMPTS = "attempts";

    private final StringRedisTemplate redisTemplate;

    public boolean tryAcquireCooldown(String phoneNumber, Duration cooldown) {
        return Boolean.TRUE.equals(
                redisTemplate.opsForValue().setIfAbsent(COOLDOWN_KEY.formatted(phoneNumber), "1", cooldown));
    }

    public long increaseDailyCount(String phoneNumber, Duration window) {
        return increaseWithin(DAILY_KEY.formatted(phoneNumber), window);
    }

    public long increaseIpCount(String clientIp, Duration window) {
        return increaseWithin(IP_KEY.formatted(clientIp), window);
    }

    public void saveCode(String phoneNumber, String codeHash, Duration ttl) {
        String key = CODE_KEY.formatted(phoneNumber);
        hashOperations().putAll(key, Map.of(FIELD_CODE_HASH, codeHash, FIELD_ATTEMPTS, "0"));
        redisTemplate.expire(key, ttl);
    }

    public Optional<String> findCodeHash(String phoneNumber) {
        return Optional.ofNullable(hashOperations().get(CODE_KEY.formatted(phoneNumber), FIELD_CODE_HASH));
    }

    public long increaseAttempts(String phoneNumber) {
        return hashOperations().increment(CODE_KEY.formatted(phoneNumber), FIELD_ATTEMPTS, 1L);
    }

    public void deleteCode(String phoneNumber) {
        redisTemplate.delete(CODE_KEY.formatted(phoneNumber));
    }

    public void saveTicket(String ticketHash, String phoneNumber, Duration ttl) {
        redisTemplate.opsForValue().set(TICKET_KEY.formatted(ticketHash), phoneNumber, ttl);
    }

    private long increaseWithin(String key, Duration window) {
        Long count = redisTemplate.opsForValue().increment(key);
        if (count != null && count == 1L) {
            redisTemplate.expire(key, window);
        }
        return count == null ? 0L : count;
    }

    private HashOperations<String, String, String> hashOperations() {
        return redisTemplate.opsForHash();
    }
}
