package com.ssafy.timo.domain.notification.scheduler;

import com.ssafy.timo.domain.notification.repository.NotificationRepository;
import com.ssafy.timo.global.config.NotificationProperties;
import com.ssafy.timo.global.config.NotificationRetentionProperties;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Clock;
import java.time.Duration;
import java.time.LocalDateTime;

/**
 * 보존 기간이 지난 알림을 지운다. 진짜로 지운다.
 *
 * <p>소프트 삭제가 아니다. 이 배치의 목적이 표가 끝없이 커지는 것을 막는 것이라 행을 남기면 목적이 사라지고,
 * 알림 본문에는 회원이 어떤 공연에 관심이 있었는지가 담겨 있어 보관 의무 없이 오래 두는 것도 좋지 않다. 분쟁의
 * 근거가 되는 거래 기록은 예매, 양도 체결, 지갑 거래 테이블에 따로 남는다. 보존 기간은 설정으로 바꿀 수 있고
 * 배치를 끌 수도 있다({@link NotificationRetentionProperties}).
 *
 * <p>한 번에 다 지우지 않는다. 조각({@value #CHUNK_SIZE}건)마다 트랜잭션을 따로 열어 지운다. 대량 삭제가 오래
 * 행을 잠가 알림함 조회와 새 알림 저장을 막는 것을 피하려는 것이다. 한 번의 실행에 지우는 조각 수에도 상한이
 * 있다. 밀린 양은 다음 날 이어서 지운다.
 *
 * <p><b>보존 기간은 보정 구간보다 충분히 길어야 한다.</b> 알림을 지우면 같은 중복 방지 키가 다시 비어서, 스윕이
 * 그 알림을 다시 찾으면 다시 저장한다. 스윕은 보정 구간 안의 알림만 다시 찾으므로 보존 기간이 그보다 길면
 * 안전하다. 그렇지 않은 설정은 기동 때 막는다.
 *
 * <p>사용량이 적은 새벽 4시 30분에 하루 한 번 돈다. 인스턴스가 여러 대여도 문제없다. 같은 행을 두 곳이 지우려
 * 하면 늦은 쪽이 0 건을 지울 뿐이다.
 */
@Slf4j
@Component
public class NotificationRetentionScheduler {

    /** 한 번에 지우는 행 수. */
    static final int CHUNK_SIZE = 1_000;

    /** 한 번의 실행에서 지우는 조각 수의 상한. 넘는 양은 다음 실행에서 이어서 지운다. */
    static final int MAX_CHUNKS_PER_RUN = 1_000;

    /** 보존 기간은 보정 구간에 이만큼의 여유를 더한 것보다 길어야 한다. */
    private static final Duration SAFETY_MARGIN = Duration.ofDays(1);

    private final NotificationRepository notificationRepository;
    private final TransactionTemplate transactionTemplate;
    private final Clock clock;
    private final NotificationRetentionProperties retention;
    private final int chunkSize;
    private final int maxChunksPerRun;

    @Autowired
    public NotificationRetentionScheduler(NotificationRepository notificationRepository,
                                          PlatformTransactionManager transactionManager, Clock clock,
                                          NotificationRetentionProperties retention,
                                          NotificationProperties notificationProperties) {
        this(notificationRepository, transactionManager, clock, retention, notificationProperties,
                CHUNK_SIZE, MAX_CHUNKS_PER_RUN);
    }

    /** 테스트가 조각 크기와 상한을 줄여 쓰려고 연 생성자. */
    NotificationRetentionScheduler(NotificationRepository notificationRepository,
                                   PlatformTransactionManager transactionManager, Clock clock,
                                   NotificationRetentionProperties retention,
                                   NotificationProperties notificationProperties,
                                   int chunkSize, int maxChunksPerRun) {
        if (retention.retentionEnabled()
                && Duration.ofDays(retention.retentionDays())
                .compareTo(notificationProperties.catchUp().plus(SAFETY_MARGIN)) < 0) {
            throw new IllegalStateException(
                    "app.notification.retention-days(%d일) 는 catch-up(%s) 에 하루를 더한 것보다 길어야 한다. "
                            .formatted(retention.retentionDays(), notificationProperties.catchUp())
                            + "짧으면 지운 알림을 스윕이 다시 저장한다.");
        }
        this.notificationRepository = notificationRepository;
        this.transactionTemplate = new TransactionTemplate(transactionManager);
        this.clock = clock;
        this.retention = retention;
        this.chunkSize = chunkSize;
        this.maxChunksPerRun = maxChunksPerRun;
    }

    /** 매일 새벽 4시 30분. 서울 기준이다. 꺼져 있으면({@code retention-enabled: false}) 아무것도 하지 않는다. */
    @Scheduled(cron = "0 30 4 * * *", zone = "Asia/Seoul")
    public void tick() {
        if (!retention.retentionEnabled()) {
            return;
        }
        try {
            purge(LocalDateTime.now(clock));
        } catch (Exception e) {
            // 다음 날 다시 돈다. 지우지 못한 것은 그대로 남아 있을 뿐이다.
            log.error("오래된 알림 삭제 실패", e);
        }
    }

    /**
     * 보존 기간이 지난 알림을 지운다. 타이머 없이 부를 수 있어 테스트가 쓴다.
     *
     * @return 지운 알림 수
     */
    public int purge(LocalDateTime now) {
        LocalDateTime cutoff = now.minusDays(retention.retentionDays());

        int total = 0;
        for (int chunk = 0; chunk < maxChunksPerRun; chunk++) {
            Integer deleted = transactionTemplate.execute(
                    status -> notificationRepository.deleteOlderThan(cutoff, chunkSize));
            int count = deleted == null ? 0 : deleted;
            total += count;
            if (count < chunkSize) {
                break; // 더 지울 것이 없다.
            }
        }

        if (total > 0) {
            log.info("오래된 알림 삭제 (deleted={}, cutoff={})", total, cutoff);
        }
        return total;
    }
}
