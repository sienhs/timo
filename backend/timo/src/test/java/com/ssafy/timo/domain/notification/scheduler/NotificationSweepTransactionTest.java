package com.ssafy.timo.domain.notification.scheduler;

import static org.assertj.core.api.Assertions.assertThat;

import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.notification.entity.NotificationType;
import com.ssafy.timo.domain.notification.scheduler.NotificationSweepScheduler.SweepResult;
import com.ssafy.timo.domain.notification.service.NotificationRecorder;
import com.ssafy.timo.domain.notification.service.NotificationRecorder.Draft;
import com.ssafy.timo.global.config.notification.NotificationProperties;
import com.ssafy.timo.support.IntegrationTest;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;
import java.util.function.IntSupplier;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * 스윕이 실제 DB 에서 스윕별로 커밋·롤백되는지 확인한다.
 *
 * <p>롤백되는 테스트 트랜잭션 안에서는 스윕마다 트랜잭션이 따로 열리는지 알 수 없다. 스윕이 테스트의
 * 트랜잭션에 합류해 버리기 때문이다. 그래서 테스트 트랜잭션을 끄고({@code NOT_SUPPORTED}) 진짜로
 * 커밋하게 둔 뒤, 만든 행을 직접 지운다. 컨텍스트는 다른 통합 테스트와 공유한다.
 */
@IntegrationTest
@Transactional(propagation = Propagation.NOT_SUPPORTED)
class NotificationSweepTransactionTest {

    @Autowired
    private NotificationRecorder recorder;

    @Autowired
    private PlatformTransactionManager transactionManager;

    @Autowired
    private Clock clock;

    @Autowired
    private NotificationProperties properties;

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private JdbcTemplate jdbc;

    private Member first;
    private Member second;
    private Member third;

    @BeforeEach
    void setUp() {
        first = member();
        second = member();
        third = member();
    }

    @AfterEach
    void cleanUp() {
        for (Member member : List.of(first, second, third)) {
            jdbc.update("delete from notification where member_id = ?", member.getId());
            jdbc.update("delete from member where member_id = ?", member.getId());
        }
    }

    @Test
    @DisplayName("실패한 스윕이 저장하던 알림은 되돌아가고, 앞뒤 스윕이 저장한 알림은 커밋된다")
    void failingSweep_rollsBackOnlyItsOwnNotifications() {
        NotificationSweepScheduler scheduler = new NotificationSweepScheduler(
                List.of(
                        sweep("before", () -> record(first)),
                        sweep("failing", () -> {
                            record(second);
                            throw new IllegalStateException("boom");
                        }),
                        sweep("after", () -> record(third))),
                transactionManager, clock, properties);

        List<SweepResult> results = scheduler.runOnce(LocalDateTime.of(2026, 9, 20, 9, 0));

        assertThat(results).containsExactly(
                new SweepResult("before", 1, false),
                new SweepResult("failing", 0, true),
                new SweepResult("after", 1, false));
        assertThat(count(first)).as("앞 스윕은 커밋된다").isEqualTo(1);
        assertThat(count(second)).as("실패한 스윕의 저장은 되돌아간다").isZero();
        assertThat(count(third)).as("실패 뒤의 스윕도 커밋된다").isEqualTo(1);
    }

    @Test
    @DisplayName("다음 주기에 같은 스윕이 다시 돌아도 이미 저장된 알림은 늘지 않는다")
    void secondRun_doesNotDuplicate() {
        NotificationSweepScheduler scheduler = new NotificationSweepScheduler(
                List.of(sweep("repeat", () -> record(first))), transactionManager, clock, properties);
        LocalDateTime now = LocalDateTime.of(2026, 9, 20, 9, 0);

        List<SweepResult> firstRun = scheduler.runOnce(now);
        List<SweepResult> secondRun = scheduler.runOnce(now.plusMinutes(1));

        assertThat(firstRun).containsExactly(new SweepResult("repeat", 1, false));
        assertThat(secondRun).containsExactly(new SweepResult("repeat", 0, false));
        assertThat(count(first)).isEqualTo(1);
    }

    private int record(Member member) {
        boolean recorded = recorder.record(Draft.of(member.getId(), NotificationType.ENTRY_OPEN, "본문", 12L,
                NotificationType.ENTRY_OPEN.concertKey(12L)));
        return recorded ? 1 : 0;
    }

    private long count(Member member) {
        return jdbc.queryForObject(
                "select count(*) from notification where member_id = ?", Long.class, member.getId());
    }

    private static NotificationSweep sweep(String name, IntSupplier body) {
        return new NotificationSweep() {
            @Override
            public String name() {
                return name;
            }

            @Override
            public int run(LocalDateTime now, int limit) {
                return body.getAsInt();
            }
        };
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
