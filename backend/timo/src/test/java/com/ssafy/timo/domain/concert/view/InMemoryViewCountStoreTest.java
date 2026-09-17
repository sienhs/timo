package com.ssafy.timo.domain.concert.view;

import org.junit.jupiter.api.Test;

import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.stream.IntStream;

import static org.assertj.core.api.Assertions.assertThat;

class InMemoryViewCountStoreTest {

    @Test
    void incrementsFromPersistedValue() {
        ViewCountStore store = new InMemoryViewCountStore();

        assertThat(store.incrementAndGet(1L, 10)).isEqualTo(11);
        assertThat(store.incrementAndGet(1L, 10)).isEqualTo(12);
    }

    @Test
    void doesNotLoseConcurrentIncrements() throws Exception {
        ViewCountStore store = new InMemoryViewCountStore();
        ExecutorService executor = Executors.newFixedThreadPool(8);
        try {
            var tasks = IntStream.range(0, 100)
                    .<Callable<Integer>>mapToObj(ignored -> () -> store.incrementAndGet(1L, 0))
                    .toList();

            for (Future<Integer> ignored : executor.invokeAll(tasks)) {
                ignored.get();
            }

            assertThat(store.incrementAndGet(1L, 0)).isEqualTo(101);
        } finally {
            executor.shutdownNow();
        }
    }
}
