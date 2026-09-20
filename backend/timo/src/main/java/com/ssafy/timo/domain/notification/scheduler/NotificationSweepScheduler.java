package com.ssafy.timo.domain.notification.scheduler;

import com.ssafy.timo.global.config.NotificationProperties;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Clock;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * 시간에 맞춰 나가는 알림 스윕들을 주기적으로 돌린다.
 *
 * <p>스윕마다 트랜잭션을 하나씩 연다. 하나로 묶으면 마지막 스윕이 실패했을 때 앞에서 저장한 알림까지 함께
 * 되돌아가고, 이미 보낸 푸시가 알림함에는 없는 것이 된다. 스윕 하나가 실패하면 그 스윕의 저장만 되돌리고
 * 나머지는 계속 돈다. 되돌아간 알림은 다음 주기에 다시 찾아지므로 잃지 않는다.
 *
 * <p>트랜잭션 경계는 여기 한 곳에만 있다. 스윕은 트랜잭션을 모르는 순수한 로직이라 테스트가 쉽고, 경계를
 * 스윕마다 어노테이션으로 흩어 두지 않는다. 푸시는 각 트랜잭션이 커밋된 뒤에 나간다.
 *
 * <p>인스턴스가 여러 대여도 락이 필요 없다. 같은 알림을 두 인스턴스가 동시에 넣으려 해도 유니크가 한쪽만
 * 통과시키고, 푸시는 통과한 쪽만 보낸다.
 *
 * <p>{@code scheduling.enabled} 가 꺼져 있으면 타이머가 뜨지 않는다({@code SchedulingConfig}). 테스트가
 * 타이머를 기다리지 않고 {@link #runOnce(LocalDateTime)} 를 직접 부를 수 있는 이유다.
 */
@Slf4j
@Component
public class NotificationSweepScheduler {

    /** 1분. 이 값이 시간 알림이 정해진 시각보다 늦어질 수 있는 최대 시간이다. */
    private static final long SWEEP_INTERVAL_MILLIS = 60_000L;

    private final List<NotificationSweep> sweeps;
    private final TransactionTemplate transactionTemplate;
    private final Clock clock;
    private final NotificationProperties properties;

    public NotificationSweepScheduler(List<NotificationSweep> sweeps, PlatformTransactionManager transactionManager,
                                      Clock clock, NotificationProperties properties) {
        this.sweeps = sweeps;
        this.transactionTemplate = new TransactionTemplate(transactionManager);
        this.clock = clock;
        this.properties = properties;
    }

    /**
     * {@code initialDelay = 0} 으로 기동 직후에도 한 번 돈다. 서버가 내려가 있던 동안 놓친 알림을 뜨는
     * 즉시 보정 구간 안에서 메우기 위해서다. 한 주기가 끝난 뒤 1분을 기다리므로 주기가 겹치지 않는다.
     */
    @Scheduled(initialDelay = 0L, fixedDelay = SWEEP_INTERVAL_MILLIS)
    public void tick() {
        runOnce(LocalDateTime.now(clock));
    }

    /**
     * 스윕을 한 번씩 돌린다. 타이머 없이 부를 수 있어 수동 트리거와 테스트가 쓴다.
     *
     * <p>모든 스윕이 같은 {@code now} 를 받는다. 앞 스윕이 오래 걸려도 뒤 스윕의 기준이 밀리지 않는다.
     *
     * @return 스윕별 결과. 실패한 스윕도 결과에 남는다
     */
    public List<SweepResult> runOnce(LocalDateTime now) {
        List<SweepResult> results = new ArrayList<>();
        int limit = properties.sweepLimit();

        for (NotificationSweep sweep : sweeps) {
            try {
                Integer recorded = transactionTemplate.execute(status -> sweep.run(now, limit));
                int count = recorded == null ? 0 : recorded;
                results.add(new SweepResult(sweep.name(), count, false));
                if (count > 0) {
                    // 아무것도 안 보낸 대부분의 주기는 남기지 않는다. 1분마다 찍으면 로그가 이것만 남는다.
                    log.info("알림 스윕 완료 (sweep={}, recorded={}, now={})", sweep.name(), count, now);
                }
            } catch (Exception e) {
                // 이 스윕의 저장은 이미 되돌아갔다. 다른 스윕은 계속 돌고, 못 보낸 알림은 다음 주기에 다시 찾는다.
                log.error("알림 스윕 실패 (sweep={}, now={})", sweep.name(), now, e);
                results.add(new SweepResult(sweep.name(), 0, true));
            }
        }
        return results;
    }

    /**
     * 스윕 하나의 결과.
     *
     * @param recorded 새로 저장한 알림 수. 실패했으면 0 이다. 그 스윕의 저장은 모두 되돌아갔다
     */
    public record SweepResult(String name, int recorded, boolean failed) {
    }
}
