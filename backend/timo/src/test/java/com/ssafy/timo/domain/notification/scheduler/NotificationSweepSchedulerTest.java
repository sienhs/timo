package com.ssafy.timo.domain.notification.scheduler;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

import com.ssafy.timo.domain.notification.scheduler.NotificationSweepScheduler.SweepResult;
import com.ssafy.timo.global.config.notification.NotificationProperties;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionStatus;
import org.springframework.transaction.support.SimpleTransactionStatus;

/**
 * 스윕을 도는 골격의 규칙을 확인한다. 트랜잭션 매니저를 흉내 내서 트랜잭션이 몇 개 열리고 무엇이
 * 커밋·롤백되는지 센다. 실제 DB 에 커밋되는지는 {@code NotificationSweepTransactionTest} 가 본다.
 */
class NotificationSweepSchedulerTest {

    private static final LocalDateTime NOW = LocalDateTime.of(2026, 9, 20, 9, 0);

    private final PlatformTransactionManager transactionManager = mock(PlatformTransactionManager.class);
    private final Clock clock = Clock.fixed(Instant.parse("2026-09-20T00:00:00Z"), ZoneId.of("Asia/Seoul"));

    private NotificationSweepScheduler scheduler(int limit, NotificationSweep... sweeps) {
        TransactionStatus status = new SimpleTransactionStatus();
        doReturn(status).when(transactionManager).getTransaction(any());
        return new NotificationSweepScheduler(
                List.of(sweeps), transactionManager, clock, new NotificationProperties(limit));
    }

    @Test
    @DisplayName("모든 스윕이 같은 기준 시각과 처리 상한을 받는다")
    void runOnce_passesSameNowAndLimitToEverySweep() {
        RecordingSweep first = new RecordingSweep("first", 2);
        RecordingSweep second = new RecordingSweep("second", 0);

        scheduler(500, first, second).runOnce(NOW);

        assertThat(first.calls).containsExactly(new Call(NOW, 500));
        assertThat(second.calls).containsExactly(new Call(NOW, 500));
    }

    @Test
    @DisplayName("스윕마다 트랜잭션이 하나씩 열리고 성공하면 각각 커밋된다")
    void runOnce_opensOneTransactionPerSweepAndCommits() {
        scheduler(500, new RecordingSweep("a", 1), new RecordingSweep("b", 1), new RecordingSweep("c", 1))
                .runOnce(NOW);

        verify(transactionManager, times(3)).getTransaction(any());
        verify(transactionManager, times(3)).commit(any());
        verify(transactionManager, never()).rollback(any());
    }

    @Test
    @DisplayName("스윕 하나가 실패하면 그 스윕만 롤백하고 나머지는 계속 돈다")
    void runOnce_failingSweep_isRolledBackAndOthersContinue() {
        RecordingSweep before = new RecordingSweep("before", 3);
        NotificationSweep failing = new NotificationSweep() {
            @Override
            public String name() {
                return "failing";
            }

            @Override
            public int run(LocalDateTime now, int limit) {
                throw new IllegalStateException("boom");
            }
        };
        RecordingSweep after = new RecordingSweep("after", 4);

        List<SweepResult> results = scheduler(500, before, failing, after).runOnce(NOW);

        assertThat(results).containsExactly(
                new SweepResult("before", 3, false),
                new SweepResult("failing", 0, true),
                new SweepResult("after", 4, false));
        assertThat(after.calls).hasSize(1);
        verify(transactionManager, times(2)).commit(any());
        verify(transactionManager, times(1)).rollback(any());
    }

    @Test
    @DisplayName("결과에는 스윕 이름과 새로 저장한 개수가 담긴다")
    void runOnce_returnsRecordedCountPerSweep() {
        List<SweepResult> results = scheduler(500, new RecordingSweep("entry", 7), new RecordingSweep("show", 0))
                .runOnce(NOW);

        assertThat(results).containsExactly(
                new SweepResult("entry", 7, false), new SweepResult("show", 0, false));
    }

    @Test
    @DisplayName("스윕이 하나도 없으면 아무것도 열지 않는다")
    void runOnce_noSweeps_doesNothing() {
        List<SweepResult> results = scheduler(500).runOnce(NOW);

        assertThat(results).isEmpty();
        verify(transactionManager, never()).getTransaction(any());
    }

    @Test
    @DisplayName("타이머가 부르는 진입점은 시계의 현재 시각을 기준으로 돈다")
    void tick_usesClockNow() {
        RecordingSweep sweep = new RecordingSweep("s", 0);

        scheduler(500, sweep).tick();

        // 고정 시계는 UTC 00:00 = 서울 09:00 이다.
        assertThat(sweep.calls).containsExactly(new Call(NOW, 500));
    }

    @Test
    @DisplayName("처리 상한이 1 미만이면 기동 단계에서 막는다")
    void properties_nonPositiveLimit_isRejected() {
        assertThatThrownBy(() -> new NotificationProperties(0)).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> new NotificationProperties(-1)).isInstanceOf(IllegalArgumentException.class);
    }

    private record Call(LocalDateTime now, int limit) {
    }

    private static final class RecordingSweep implements NotificationSweep {

        private final String name;
        private final int recorded;
        private final List<Call> calls = new ArrayList<>();

        private RecordingSweep(String name, int recorded) {
            this.name = name;
            this.recorded = recorded;
        }

        @Override
        public String name() {
            return name;
        }

        @Override
        public int run(LocalDateTime now, int limit) {
            calls.add(new Call(now, limit));
            return recorded;
        }
    }
}
