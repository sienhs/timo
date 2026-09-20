package com.ssafy.timo.domain.notification.scheduler;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.notification.repository.NotificationRepository;
import com.ssafy.timo.global.config.notification.NotificationProperties;
import com.ssafy.timo.global.config.notification.NotificationRetentionProperties;
import com.ssafy.timo.support.IntegrationTest;
import java.lang.reflect.Method;
import java.time.Clock;
import java.time.Duration;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.scheduling.support.CronExpression;
import org.springframework.transaction.PlatformTransactionManager;

/**
 * 오래된 알림 삭제 배치가 보존 기간이 지난 알림만, 나눠서, 정해진 상한 안에서 지우는지 실제 MySQL 로 확인한다.
 *
 * <p>가장 위험한 것은 지우면 안 되는 알림을 지우는 것이다. 경계는 초 단위로 보고, 다른 회원의 최근 알림이
 * 그대로인지도 함께 본다.
 */
@IntegrationTest
class NotificationRetentionSchedulerTest {

    private static final ZoneId SEOUL = ZoneId.of("Asia/Seoul");

    /** 배치가 도는 시각. 보존 90일이면 기준선은 2026-06-22 04:30 이다. */
    private static final LocalDateTime NOW = LocalDateTime.of(2026, 9, 20, 4, 30);
    private static final LocalDateTime CUTOFF = LocalDateTime.of(2026, 6, 22, 4, 30);

    @Autowired
    private NotificationRepository notificationRepository;

    @Autowired
    private PlatformTransactionManager transactionManager;

    @Autowired
    private NotificationRetentionProperties defaultRetention;

    @Autowired
    private NotificationProperties notificationProperties;

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private JdbcTemplate jdbc;

    private Member member;
    private int sequence;

    @BeforeEach
    void setUp() {
        member = member();
    }

    @Test
    @DisplayName("보존 기간이 지난 알림만 지우고, 기준선 정각과 그 이후는 남긴다")
    void purge_deletesOnlyOlderThanCutoff() {
        insert(member, CUTOFF.minusSeconds(1));   // 지운다
        insert(member, CUTOFF);                    // 정확히 기준선이다. 남긴다
        insert(member, CUTOFF.plusSeconds(1));    // 남긴다
        insert(member, NOW.minusDays(1));          // 남긴다

        int deleted = scheduler(3, 100).purge(NOW);

        assertThat(deleted).isEqualTo(1);
        assertThat(remaining(member)).isEqualTo(3);
        assertThat(oldestCreatedAt(member)).isEqualTo(CUTOFF);
    }

    @Test
    @DisplayName("읽었는지와 상관없이 오래된 알림을 지운다")
    void purge_deletesReadAndUnreadAlike() {
        long read = insert(member, CUTOFF.minusDays(1));
        insert(member, CUTOFF.minusDays(2));
        jdbc.update("update notification set read_at = ? where notification_id = ?", CUTOFF, read);

        int deleted = scheduler(3, 100).purge(NOW);

        assertThat(deleted).isEqualTo(2);
        assertThat(remaining(member)).isZero();
    }

    @Test
    @DisplayName("한 조각을 넘는 양도 조각을 이어서 끝까지 지운다")
    void purge_continuesAcrossChunks() {
        for (int i = 0; i < 10; i++) {
            insert(member, CUTOFF.minusDays(1 + i));
        }
        insert(member, NOW.minusDays(1));
        insert(member, NOW);

        int deleted = scheduler(3, 100).purge(NOW);

        assertThat(deleted).as("3 + 3 + 3 + 1").isEqualTo(10);
        assertThat(remaining(member)).isEqualTo(2);
    }

    @Test
    @DisplayName("지울 양이 조각 크기의 정확한 배수여도 끝까지 지우고 끝난다")
    void purge_exactMultipleOfChunk_finishes() {
        for (int i = 0; i < 6; i++) {
            insert(member, CUTOFF.minusDays(1 + i));
        }

        assertThat(scheduler(3, 100).purge(NOW)).isEqualTo(6);
        assertThat(remaining(member)).isZero();
    }

    @Test
    @DisplayName("한 번의 실행에서 지우는 조각 수에는 상한이 있고, 남은 양은 다음 실행이 이어서 지운다")
    void purge_respectsChunkCapAndContinuesNextRun() {
        for (int i = 0; i < 10; i++) {
            insert(member, CUTOFF.minusDays(1 + i));
        }
        NotificationRetentionScheduler capped = scheduler(2, 2);

        int first = capped.purge(NOW);
        int second = capped.purge(NOW);
        int third = capped.purge(NOW);

        assertThat(first).as("2건씩 2조각").isEqualTo(4);
        assertThat(second).isEqualTo(4);
        assertThat(third).isEqualTo(2);
        assertThat(remaining(member)).isZero();
    }

    @Test
    @DisplayName("오래된 알림이 오래된 순서로 지워져서, 상한에 걸려도 가장 오래된 것부터 사라진다")
    void purge_deletesOldestFirst() {
        insert(member, CUTOFF.minusDays(1));      // 가장 최근이지만 기준선 밖이다
        insert(member, CUTOFF.minusDays(30));
        insert(member, CUTOFF.minusDays(60));
        insert(member, CUTOFF.minusDays(10));

        // 2건씩 1조각만 지운다. 넷 중 가장 오래된 둘(60일 전, 30일 전)이 사라진다.
        scheduler(2, 1).purge(NOW);

        assertThat(jdbc.queryForList("select created_at from notification where member_id = ? order by created_at",
                java.sql.Timestamp.class, member.getId()))
                .extracting(java.sql.Timestamp::toLocalDateTime)
                .containsExactly(CUTOFF.minusDays(10), CUTOFF.minusDays(1));
    }

    @Test
    @DisplayName("다른 회원의 오래된 알림도 지우고 최근 알림은 회원과 무관하게 남긴다")
    void purge_worksAcrossMembers() {
        Member other = member();
        insert(member, CUTOFF.minusDays(1));
        insert(other, CUTOFF.minusDays(1));
        insert(other, NOW.minusHours(1));

        int deleted = scheduler(3, 100).purge(NOW);

        assertThat(deleted).isEqualTo(2);
        assertThat(remaining(member)).isZero();
        assertThat(remaining(other)).isEqualTo(1);
    }

    @Test
    @DisplayName("지울 것이 없으면 0건이다")
    void purge_nothingOld_returnsZero() {
        insert(member, NOW.minusDays(1));

        assertThat(scheduler(3, 100).purge(NOW)).isZero();
        assertThat(remaining(member)).isEqualTo(1);
    }

    @Test
    @DisplayName("타이머가 부르는 진입점은 시계의 현재 시각을 기준으로 지운다")
    void tick_usesClockAndDeletes() {
        insert(member, CUTOFF.minusDays(1));

        scheduler(3, 100).tick();

        assertThat(remaining(member)).isZero();
    }

    @Test
    @DisplayName("꺼져 있으면 타이머가 불려도 아무것도 지우지 않는다")
    void tick_whenDisabled_deletesNothing() {
        insert(member, CUTOFF.minusDays(1));
        NotificationRetentionScheduler disabled = new NotificationRetentionScheduler(notificationRepository,
                transactionManager, fixedClock(), new NotificationRetentionProperties(90, false),
                notificationProperties, 3, 100);

        disabled.tick();

        assertThat(remaining(member)).isEqualTo(1);
    }

    @Test
    @DisplayName("보존 기간이 보정 구간에 하루를 더한 것보다 짧으면 기동 때 막는다")
    void construction_retentionShorterThanCatchUpPlusMargin_isRejected() {
        NotificationProperties oneHourCatchUp = new NotificationProperties(500, Duration.ofHours(1));

        assertThatThrownBy(() -> new NotificationRetentionScheduler(notificationRepository, transactionManager,
                fixedClock(), new NotificationRetentionProperties(1, true), oneHourCatchUp, 3, 100))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("catch-up");

        // 하루 + 1시간 = 25시간. 2일이면 통과한다.
        new NotificationRetentionScheduler(notificationRepository, transactionManager, fixedClock(),
                new NotificationRetentionProperties(2, true), oneHourCatchUp, 3, 100);
    }

    @Test
    @DisplayName("배치를 꺼 두면 보존 기간이 짧아도 기동을 막지 않는다")
    void construction_whenDisabled_skipsRetentionCheck() {
        new NotificationRetentionScheduler(notificationRepository, transactionManager, fixedClock(),
                new NotificationRetentionProperties(1, false),
                new NotificationProperties(500, Duration.ofDays(7)), 3, 100);
    }

    @Test
    @DisplayName("보존 일수가 1 미만이면 설정 자체를 받지 않는다")
    void properties_nonPositiveRetentionDays_isRejected() {
        assertThatThrownBy(() -> new NotificationRetentionProperties(0, true))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> new NotificationRetentionProperties(-5, true))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    @DisplayName("설정이 없으면 90일 보존이고 켜져 있다")
    void properties_haveDefaults() {
        assertThat(defaultRetention.retentionDays()).isEqualTo(90);
        assertThat(defaultRetention.retentionEnabled()).isTrue();
    }

    @Test
    @DisplayName("매일 새벽 4시 30분, 서울 시각에 돈다")
    void tick_isScheduledDailyAtFourThirtySeoul() throws NoSuchMethodException {
        Method tick = NotificationRetentionScheduler.class.getMethod("tick");
        Scheduled scheduled = tick.getAnnotation(Scheduled.class);

        assertThat(scheduled.zone()).isEqualTo("Asia/Seoul");
        CronExpression cron = CronExpression.parse(scheduled.cron());
        assertThat(cron.next(LocalDateTime.of(2026, 9, 20, 4, 29, 59)))
                .isEqualTo(LocalDateTime.of(2026, 9, 20, 4, 30));
        assertThat(cron.next(LocalDateTime.of(2026, 9, 20, 4, 30)))
                .isEqualTo(LocalDateTime.of(2026, 9, 21, 4, 30));
    }

    @Test
    @DisplayName("생성 시각 인덱스가 있어 지울 것을 찾으려고 표 전체를 훑지 않는다")
    void schema_hasCreatedAtIndex() {
        List<String> columns = jdbc.queryForList("""
                select column_name from information_schema.statistics
                 where table_schema = database() and table_name = 'notification'
                   and index_name = 'idx_notification_created'
                 order by seq_in_index
                """, String.class);

        assertThat(columns).containsExactly("created_at");
    }

    // ---------------------------------------------------------------- 헬퍼

    private NotificationRetentionScheduler scheduler(int chunkSize, int maxChunks) {
        return new NotificationRetentionScheduler(notificationRepository, transactionManager, fixedClock(),
                new NotificationRetentionProperties(90, true), notificationProperties, chunkSize, maxChunks);
    }

    private static Clock fixedClock() {
        return Clock.fixed(NOW.atZone(SEOUL).toInstant(), SEOUL);
    }

    /** 만든 시각을 지정해 알림을 넣는다. 저장 쿼리가 생성 시각을 인자로 받는 것을 이용한다. */
    private long insert(Member owner, LocalDateTime createdAt) {
        String dedupKey = "TEST:" + sequence++;
        notificationRepository.insertIgnore(owner.getId(), "ENTRY_OPEN", "본문", "CONCERT", 1L, dedupKey, createdAt);
        return notificationRepository.findIdByMemberIdAndDedupKey(owner.getId(), dedupKey).orElseThrow();
    }

    private long remaining(Member owner) {
        return jdbc.queryForObject(
                "select count(*) from notification where member_id = ?", Long.class, owner.getId());
    }

    private LocalDateTime oldestCreatedAt(Member owner) {
        return jdbc.queryForObject(
                "select min(created_at) from notification where member_id = ?", java.sql.Timestamp.class,
                owner.getId()).toLocalDateTime();
    }

    private Member member() {
        String suffix = UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        return memberRepository.save(Member.builder()
                .phoneNumber("010" + suffix.replaceAll("[a-z]", "1"))
                .name("정희성")
                .nickname("티모" + suffix)
                .build());
    }
}
