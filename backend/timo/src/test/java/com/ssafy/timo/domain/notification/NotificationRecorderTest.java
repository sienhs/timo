package com.ssafy.timo.domain.notification;

import static org.assertj.core.api.Assertions.assertThat;

import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.notification.entity.LinkType;
import com.ssafy.timo.domain.notification.entity.NotificationType;
import com.ssafy.timo.domain.notification.service.NotificationBatchCreatedEvent;
import com.ssafy.timo.domain.notification.service.NotificationCreatedEvent;
import com.ssafy.timo.domain.notification.service.NotificationRecorder;
import com.ssafy.timo.domain.notification.service.NotificationRecorder.Draft;
import com.ssafy.timo.support.IntegrationTest;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Stream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.event.ApplicationEvents;
import org.springframework.test.context.event.RecordApplicationEvents;

/**
 * 모든 알림이 지나는 진입점의 규칙을 확인한다: 중복은 넣지 않고, 새로 넣은 건에만 이벤트를 낸다.
 *
 * <p>이 테스트는 롤백되는 트랜잭션 안에서 돌기 때문에 커밋 이후 수신자는 호출되지 않는다.
 * 여기서 보는 것은 "이벤트가 발행되는가" 까지이고, 커밋 이후 발송은 수신자 쪽 테스트의 몫이다.
 */
@IntegrationTest
@RecordApplicationEvents
class NotificationRecorderTest {

    @Autowired
    private NotificationRecorder recorder;

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private JdbcTemplate jdbc;

    @Autowired
    private ApplicationEvents events;

    @Test
    @DisplayName("새 알림은 저장되고 이벤트가 한 번 발행된다")
    void record_newNotification_savedAndPublished() {
        Member member = member();

        boolean recorded = recorder.record(entryOpen(member.getId(), 12L));

        assertThat(recorded).isTrue();
        assertThat(count(member.getId())).isEqualTo(1);
        assertThat(created()).hasSize(1);
    }

    @Test
    @DisplayName("같은 알림을 다시 넣으면 false 이고 이벤트도 다시 나가지 않는다")
    void record_duplicate_returnsFalseAndPublishesNothing() {
        Member member = member();
        recorder.record(entryOpen(member.getId(), 12L));

        boolean again = recorder.record(entryOpen(member.getId(), 12L));

        assertThat(again).isFalse();
        assertThat(count(member.getId())).isEqualTo(1);
        assertThat(created()).hasSize(1);
    }

    @Test
    @DisplayName("이벤트는 저장된 행의 id 와 알림 내용을 그대로 싣는다")
    void record_event_carriesStoredRowIdAndContent() {
        Member member = member();

        recorder.record(entryOpen(member.getId(), 12L));

        Long storedId = jdbc.queryForObject(
                "select notification_id from notification where member_id = ?", Long.class, member.getId());
        NotificationCreatedEvent event = created().findFirst().orElseThrow();
        assertThat(event.notificationId()).isEqualTo(storedId);
        assertThat(event.memberId()).isEqualTo(member.getId());
        assertThat(event.type()).isEqualTo(NotificationType.ENTRY_OPEN);
        assertThat(event.body()).isEqualTo("본문");
        assertThat(event.linkType()).isEqualTo(LinkType.CONCERT);
        assertThat(event.linkId()).isEqualTo(12L);
    }

    @Test
    @DisplayName("회원이 없어 들어가지 못하면 false 이고 이벤트는 나가지 않는다")
    void record_unknownMember_returnsFalseAndPublishesNothing() {
        boolean recorded = recorder.record(entryOpen(Long.MAX_VALUE, 12L));

        assertThat(recorded).isFalse();
        assertThat(created()).isEmpty();
    }

    @Test
    @DisplayName("여러 회원에게 넣을 때 이미 받은 회원은 건너뛰고 새로 들어간 만큼만 센다")
    void recordAll_sameBody_countsOnlyNewOnes() {
        Member a = member();
        Member b = member();
        Member c = member();
        String key = NotificationType.ENTRY_OPEN.concertKey(12L);
        recorder.record(Draft.of(b.getId(), NotificationType.ENTRY_OPEN, "본문", 12L, key));
        events.clear();

        int recorded = recorder.recordAll(
                List.of(a.getId(), b.getId(), c.getId()), NotificationType.ENTRY_OPEN, "본문", 12L, key);

        assertThat(recorded).isEqualTo(2);
        assertThat(created())
                .extracting(NotificationCreatedEvent::memberId)
                .containsExactlyInAnyOrder(a.getId(), c.getId());
    }

    @Test
    @DisplayName("회원마다 본문이 다른 알림도 각자의 본문으로 저장된다")
    void recordAll_drafts_storeEachBody() {
        Member a = member();
        Member b = member();
        String key = NotificationType.MARKET_NEW_LISTING.dateKey(java.time.LocalDate.of(2026, 9, 20));

        int recorded = recorder.recordAll(List.of(
                new Draft(a.getId(), NotificationType.MARKET_NEW_LISTING, "A의 본문", LinkType.MARKET, null, key),
                new Draft(b.getId(), NotificationType.MARKET_NEW_LISTING, "B의 본문", LinkType.CONCERT, 7L, key)));

        assertThat(recorded).isEqualTo(2);
        Map<String, Object> rowA = row(a.getId());
        Map<String, Object> rowB = row(b.getId());
        assertThat(rowA.get("body")).isEqualTo("A의 본문");
        assertThat(rowA.get("link_type")).isEqualTo("MARKET");
        assertThat(rowA.get("link_id")).isNull();
        assertThat(rowB.get("body")).isEqualTo("B의 본문");
        assertThat(rowB.get("link_type")).isEqualTo("CONCERT");
    }

    @Test
    @DisplayName("한 번에 여러 건을 넣으면 이벤트는 하나로 묶여 나가고 새로 들어간 건만 담긴다")
    void recordAll_publishesOneBatchWithOnlyNewOnes() {
        Member a = member();
        Member b = member();
        String key = NotificationType.ENTRY_OPEN.concertKey(12L);
        recorder.record(Draft.of(b.getId(), NotificationType.ENTRY_OPEN, "본문", 12L, key));
        events.clear();

        recorder.recordAll(List.of(a.getId(), b.getId()), NotificationType.ENTRY_OPEN, "본문", 12L, key);

        List<NotificationBatchCreatedEvent> batches =
                events.stream(NotificationBatchCreatedEvent.class).toList();
        assertThat(batches).hasSize(1);
        assertThat(batches.get(0).notifications())
                .extracting(NotificationCreatedEvent::memberId).containsExactly(a.getId());
    }

    @Test
    @DisplayName("전부 중복이면 빈 이벤트도 내보내지 않는다")
    void recordAll_allDuplicates_publishesNothing() {
        Member a = member();
        String key = NotificationType.ENTRY_OPEN.concertKey(12L);
        recorder.record(Draft.of(a.getId(), NotificationType.ENTRY_OPEN, "본문", 12L, key));
        events.clear();

        int recorded = recorder.recordAll(List.of(a.getId()), NotificationType.ENTRY_OPEN, "본문", 12L, key);

        assertThat(recorded).isZero();
        assertThat(events.stream(NotificationBatchCreatedEvent.class)).isEmpty();
    }

    /** 묶음 이벤트에 실린 알림들을 펼친다. */
    private Stream<NotificationCreatedEvent> created() {
        return events.stream(NotificationBatchCreatedEvent.class)
                .flatMap(batch -> batch.notifications().stream());
    }

    private static Draft entryOpen(Long memberId, Long concertId) {
        return Draft.of(memberId, NotificationType.ENTRY_OPEN, "본문", concertId,
                NotificationType.ENTRY_OPEN.concertKey(concertId));
    }

    private long count(Long memberId) {
        return jdbc.queryForObject(
                "select count(*) from notification where member_id = ?", Long.class, memberId);
    }

    private Map<String, Object> row(Long memberId) {
        return jdbc.queryForMap(
                "select body, link_type, link_id from notification where member_id = ?", memberId);
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
