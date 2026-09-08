package com.ssafy.timo.domain.auth.repository;

import jakarta.annotation.PreDestroy;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import org.springframework.stereotype.Repository;

/**
 * 단일 애플리케이션 프로세스용 저장소. 재시작·배포 시 인증 상태와 제한 횟수가 초기화된다.
 * 모든 접근을 동기화하며 만료 데이터는 1분마다 정리한다.
 */
@Repository
public class SmsVerificationStore {
    private final Clock clock;
    private final Map<String, Entry> entries = new HashMap<>();
    private final ScheduledExecutorService cleaner;

    public SmsVerificationStore() {
        this(Clock.systemUTC());
    }

    SmsVerificationStore(Clock clock) {
        this.clock = clock;
        cleaner = Executors.newSingleThreadScheduledExecutor(task -> {
            Thread thread = new Thread(task, "sms-store-cleanup");
            thread.setDaemon(true);
            return thread;
        });
        cleaner.scheduleWithFixedDelay(this::removeExpired, 1, 1, TimeUnit.MINUTES);
    }

    public synchronized boolean tryAcquireCooldown(String phoneNumber, Duration cooldown) {
        String key = "cooldown:" + phoneNumber;
        if (live(key) != null) {
            return false;
        }
        entries.put(key, entry("", cooldown));
        return true;
    }

    public synchronized long increaseDailyCount(String phoneNumber, Duration window) {
        return increaseWithin("daily:" + phoneNumber, window);
    }

    public synchronized long increaseIpCount(String clientIp, Duration window) {
        return increaseWithin("ip:" + clientIp, window);
    }

    public synchronized void saveCode(String phoneNumber, String codeHash, Duration ttl) {
        entries.put("code:" + phoneNumber, entry(codeHash, ttl));
    }

    public synchronized Optional<String> findCodeHash(String phoneNumber) {
        Entry value = live("code:" + phoneNumber);
        return value == null ? Optional.empty() : Optional.of(value.value);
    }

    public synchronized long increaseAttempts(String phoneNumber) {
        Entry value = live("code:" + phoneNumber);
        // 만료된 인증번호를 카운터 증가로 다시 생성하지 않는다.
        if (value == null) {
            throw new com.ssafy.timo.domain.auth.exception.SmsCodeNotFoundException();
        }
        return ++value.count;
    }

    public synchronized void deleteCode(String phoneNumber) {
        entries.remove("code:" + phoneNumber);
    }

    public synchronized void saveTicket(String ticketHash, String phoneNumber, Duration ttl) {
        entries.put("ticket:" + ticketHash, entry(phoneNumber, ttl));
    }

    private long increaseWithin(String key, Duration window) {
        Entry value = live(key);
        if (value == null) {
            value = entry("", window);
            entries.put(key, value);
        }
        // 후속 요청은 최초 요청에서 시작한 만료 시간을 연장하지 않는다.
        return ++value.count;
    }

    private Entry entry(String value, Duration ttl) {
        if (ttl.isZero() || ttl.isNegative()) {
            throw new IllegalArgumentException("TTL must be positive");
        }
        return new Entry(value, clock.instant().plus(ttl));
    }

    private Entry live(String key) {
        Entry value = entries.get(key);
        if (value != null && !clock.instant().isBefore(value.expiresAt)) {
            entries.remove(key);
            return null;
        }
        return value;
    }

    synchronized void removeExpired() {
        Instant now = clock.instant();
        entries.values().removeIf(value -> !now.isBefore(value.expiresAt));
    }

    synchronized int size() {
        return entries.size();
    }

    @PreDestroy
    public void close() {
        cleaner.shutdownNow();
    }

    private static final class Entry {
        private final String value;
        private final Instant expiresAt;
        private long count;

        private Entry(String value, Instant expiresAt) {
            this.value = value;
            this.expiresAt = expiresAt;
        }
    }
}

// 기존 Redis 구현: 다중 인스턴스로 전환할 때 참고한다.
// 메모리 구현과 동시에 활성화하지 않는다.
// package com.ssafy.timo.domain.auth.repository;
//
// import java.time.Duration;
// import java.util.Map;
// import java.util.Optional;
// import lombok.RequiredArgsConstructor;
// import org.springframework.data.redis.core.HashOperations;
// import org.springframework.data.redis.core.StringRedisTemplate;
// import org.springframework.stereotype.Repository;
//
// @Repository
// @RequiredArgsConstructor
// public class SmsVerificationStore {
//
//     private static final String CODE_KEY = "sms:code:%s";
//     private static final String COOLDOWN_KEY = "sms:limit:cooldown:%s";
//     private static final String DAILY_KEY = "sms:limit:daily:%s";
//     private static final String IP_KEY = "sms:limit:ip:%s";
//     private static final String TICKET_KEY = "sms:ticket:%s";
//
//     private static final String FIELD_CODE_HASH = "codeHash";
//     private static final String FIELD_ATTEMPTS = "attempts";
//
//     private final StringRedisTemplate redisTemplate;
//
//     public boolean tryAcquireCooldown(String phoneNumber, Duration cooldown) {
//         return Boolean.TRUE.equals(
//                 redisTemplate.opsForValue().setIfAbsent(COOLDOWN_KEY.formatted(phoneNumber), "1", cooldown));
//     }
//
//     public long increaseDailyCount(String phoneNumber, Duration window) {
//         return increaseWithin(DAILY_KEY.formatted(phoneNumber), window);
//     }
//
//     public long increaseIpCount(String clientIp, Duration window) {
//         return increaseWithin(IP_KEY.formatted(clientIp), window);
//     }
//
//     public void saveCode(String phoneNumber, String codeHash, Duration ttl) {
//         String key = CODE_KEY.formatted(phoneNumber);
//         hashOperations().putAll(key, Map.of(FIELD_CODE_HASH, codeHash, FIELD_ATTEMPTS, "0"));
//         redisTemplate.expire(key, ttl);
//     }
//
//     public Optional<String> findCodeHash(String phoneNumber) {
//         return Optional.ofNullable(hashOperations().get(CODE_KEY.formatted(phoneNumber), FIELD_CODE_HASH));
//     }
//
//     public long increaseAttempts(String phoneNumber) {
//         return hashOperations().increment(CODE_KEY.formatted(phoneNumber), FIELD_ATTEMPTS, 1L);
//     }
//
//     public void deleteCode(String phoneNumber) {
//         redisTemplate.delete(CODE_KEY.formatted(phoneNumber));
//     }
//
//     public void saveTicket(String ticketHash, String phoneNumber, Duration ttl) {
//         redisTemplate.opsForValue().set(TICKET_KEY.formatted(ticketHash), phoneNumber, ttl);
//     }
//
//     private long increaseWithin(String key, Duration window) {
//         Long count = redisTemplate.opsForValue().increment(key);
//         if (count != null && count == 1L) {
//             redisTemplate.expire(key, window);
//         }
//         return count == null ? 0L : count;
//     }
//
//     private HashOperations<String, String, String> hashOperations() {
//         return redisTemplate.opsForHash();
//     }
// }
