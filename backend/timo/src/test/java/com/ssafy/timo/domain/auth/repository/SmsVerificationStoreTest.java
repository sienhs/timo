package com.ssafy.timo.domain.auth.repository;

import com.ssafy.timo.domain.auth.exception.SmsCodeNotFoundException;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.concurrent.Callable;
import java.util.concurrent.Executors;
import java.util.stream.IntStream;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class SmsVerificationStoreTest {
    private final MutableClock clock = new MutableClock();
    private final SmsVerificationStore store = new SmsVerificationStore(clock);

    @AfterEach
    void close() {
        store.close();
    }

    @Test
    void cooldownExpiresAtBoundaryAndIsIndependentPerPhone() {
        assertTrue(store.tryAcquireCooldown("a", Duration.ofMinutes(1)));
        assertFalse(store.tryAcquireCooldown("a", Duration.ofMinutes(1)));
        assertTrue(store.tryAcquireCooldown("b", Duration.ofMinutes(1)));
        clock.advance(Duration.ofMinutes(1));
        assertTrue(store.tryAcquireCooldown("a", Duration.ofMinutes(1)));
    }

    @Test
    void countersKeepTheirOriginalExpiryAndSeparateNamespaces() {
        assertEquals(1, store.increaseDailyCount("same", Duration.ofHours(1)));
        assertEquals(1, store.increaseIpCount("same", Duration.ofHours(1)));
        clock.advance(Duration.ofMinutes(59));
        assertEquals(2, store.increaseDailyCount("same", Duration.ofHours(1)));
        clock.advance(Duration.ofMinutes(1));
        assertEquals(1, store.increaseDailyCount("same", Duration.ofHours(1)));
    }

    @Test
    void replacingCodeResetsAttemptsAndExpiredCodeCannotBeRevived() {
        store.saveCode("a", "first", Duration.ofMinutes(3));
        assertEquals("first", store.findCodeHash("a").orElseThrow());
        assertEquals(1, store.increaseAttempts("a"));
        store.saveCode("a", "second", Duration.ofMinutes(3));
        assertEquals(1, store.increaseAttempts("a"));
        clock.advance(Duration.ofMinutes(3));
        assertTrue(store.findCodeHash("a").isEmpty());
        assertThrows(SmsCodeNotFoundException.class, () -> store.increaseAttempts("a"));
        assertEquals(0, store.size());
    }

    @Test
    void cleanupReclaimsTicketsAndUntouchedExpiredEntries() {
        store.saveTicket("ticket", "a", Duration.ofMinutes(10));
        store.saveCode("a", "hash", Duration.ofMinutes(3));
        store.tryAcquireCooldown("a", Duration.ofMinutes(1));
        clock.advance(Duration.ofMinutes(3));
        store.removeExpired();
        assertEquals(1, store.size());
        clock.advance(Duration.ofMinutes(7));
        store.removeExpired();
        assertEquals(0, store.size());
    }

    @Test
    void concurrentRequestsDoNotLoseCountsOrAcquireCooldownTwice() throws Exception {
        try (var pool = Executors.newFixedThreadPool(8)) {
            var cooldowns = pool.invokeAll(IntStream.range(0, 100)
                    .mapToObj(i -> (Callable<Boolean>) () ->
                            store.tryAcquireCooldown("a", Duration.ofMinutes(1)))
                    .toList());
            int acquired = 0;
            for (var result : cooldowns) {
                if (result.get()) acquired++;
            }
            assertEquals(1, acquired);
            var counts = pool.invokeAll(IntStream.range(0, 100)
                    .mapToObj(i -> (Callable<Long>) () ->
                            store.increaseDailyCount("a", Duration.ofDays(1)))
                    .toList());
            for (var result : counts) result.get();
            assertEquals(101, store.increaseDailyCount("a", Duration.ofDays(1)));
        }
    }

    @Test
    void deletingCodePreservesOtherStateAndNewStoreStartsEmpty() {
        store.saveCode("a", "hash", Duration.ofMinutes(3));
        store.increaseDailyCount("a", Duration.ofDays(1));
        store.deleteCode("a");
        assertTrue(store.findCodeHash("a").isEmpty());
        assertEquals(2, store.increaseDailyCount("a", Duration.ofDays(1)));
        var restarted = new SmsVerificationStore(clock);
        try {
            assertTrue(restarted.findCodeHash("a").isEmpty());
            assertEquals(1, restarted.increaseDailyCount("a", Duration.ofDays(1)));
        } finally {
            restarted.close();
        }
    }

    private static final class MutableClock extends Clock {
        private Instant now = Instant.parse("2026-01-01T00:00:00Z");
        void advance(Duration duration) { now = now.plus(duration); }
        @Override public ZoneId getZone() { return ZoneOffset.UTC; }
        @Override public Clock withZone(ZoneId zone) { return this; }
        @Override public Instant instant() { return now; }
    }
}
